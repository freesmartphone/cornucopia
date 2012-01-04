/*
 * Copyright (C) 2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2012 Denis 'GNUtoo' Carikli <GNUtoo@no-log.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */
extern int snd_pcm_format_set_silence (Alsa.PcmFormat format,void * data, uint samples );


/**
 * @class RingBuffer
 *
 * Provides a ring buffer for alsa frames
 **/
errordomain RingError {
    Overflow,
    Underflow
}

class RingBuffer : GLib.Object
{
    private uint8[] ring;
    private int ring_head;
    private int ring_tail;
    private int ring_size;

     public int free;
     public int avail;


    public RingBuffer( int size )
    {
        this.ring = new uint8[size];
        this.ring_head = 0;
        this.ring_tail = 0;
        this.ring_size = size;
    }

    public void logInfos()
    {
          assert ( FsoFramework.theLogger.info ( @"<RingBuffer.Status> ring_tail: $(ring_tail) ring_head: $(ring_head) ring_size: $(ring_size) avail: $(avail) free: $(free)" ) );
    }



    public void write( uint8[] x, int count ) throws RingError
    {
        int new_ring_head = (ring_head + count) % ring_size;
        this.free = (ring_size + ring_tail - ring_head) % ring_size;
        this.avail = (ring_size + ring_head - ring_tail) % ring_size;

        if ( this.free == 0 )
            this.free = ring_size;
        stderr.printf( "RingBuffer.write: ring_head=%d, ring_tail=%d, count=%d, free=%d\n", ring_head, ring_tail, count, this.free );
        if ( count > this.free )
        {
            throw new RingError.Overflow( @"Buffer is full (free: $free / wanted to write: $count)" );
        }

        stderr.printf( "RingBuffer.write: new ring_head would be %d\n", new_ring_head );
        /* check wraparound */
        if ( new_ring_head == 0 || new_ring_head > ring_head )
        {
            /* check next line for +-1 errors I made! */
            stdout.printf( "RingBuffer.write: does not overlap - chunk = %d\n", count );
            Memory.copy( &ring[ring_head], x, count );
        }
        else
        {
            stdout.printf( "RingBuffer.write: does overlap - first chunk = %d\n", ring_size - ring_head );
            /* check next 2 lines for +-1 errors I made! */
            Memory.copy( &ring[ring_head], x, ring_size - ring_head );
            stdout.printf( "RingBuffer.write: second chunk = %d\n", ring_size - ring_head );
            Memory.copy( &ring[0], &x[ring_size - ring_head], count - (ring_size - ring_head) );
        }
        ring_head = new_ring_head;
    }

    /* we pass the pointer to buffer as a parameter, so you can use existing buffers */
    /* wouldn't want the function to malloc a new buffer each time */
    public void read( uint8[] x, int count ) throws RingError
    {
        this.avail = (ring_size + ring_head - ring_tail) % ring_size;
        this.free = (ring_size + ring_tail - ring_head) % ring_size;

        stderr.printf( "RingBuffer.read: ring_head=%d, ring_tail=%d, count=%d, avail=%d\n", ring_head, ring_tail, count, this.avail );
        if ( this.avail < count )
        {
            throw new RingError.Underflow( @"Buffer has only $avail bytes available ($count requested)" );
        }

        int new_ring_tail = (ring_tail + count) % ring_size;
        stderr.printf( "RingBuffer.read: new_ring_tail would be %d\n", new_ring_tail );

        if ( new_ring_tail == 0 || new_ring_tail > ring_tail )
        {
            stderr.printf( "RingBuffer.read: does not wrap - chunk = %d\n", count );
            Memory.copy( x, &ring[ring_tail], count );
        }
        else
        {
            stderr.printf( "RingBuffer.read: does overwrap - first chunk = %d\n", ring_size - ring_tail );
            Memory.copy( x, &ring[ring_tail], ring_size - ring_tail );
            stderr.printf( "RingBuffer.read: second chunk = %d\n", count - (ring_size - ring_tail) );
            Memory.copy( &x[ring_size - ring_tail], ring, count - (ring_size - ring_tail) );
        }
        ring_tail = new_ring_tail;
    }

    public void reset()
    {
        ring_tail = ring_head = 0;
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////

public class PlaybackFromModem : FsoFramework.AbstractObject
{
    private FsoAudio.PcmDevice modemPCM;
    private FsoAudio.PcmDevice codecPCM;

    private RingBuffer transferBuffer;
    private Alsa.PcmUnsignedFrames modemBufferSize;
    private Alsa.PcmUnsignedFrames codecBufferSize;
    private Alsa.PcmUnsignedFrames modemPeriodSize;
    private Alsa.PcmUnsignedFrames codecPeriodSize;
    private int frameSize;
    private int runRecord = 0; //it's an int to be atomic
    private int runPlayback = 0; //it's an int to be atomic
    private bool status;


    private Cond conditionalWait = new Cond();
    private Mutex readyToRead = new Mutex();

    private unowned Thread<void *> recordThread = null;
    private unowned Thread<void *> playbackThread = null;


    public PlaybackFromModem()
    {
        /* TODO: Close the sound cards and re-open later */
        Alsa.PcmFormat format = Alsa.PcmFormat.S16_LE; //TODO: make that configurable or automatic
        Alsa.PcmAccess access = Alsa.PcmAccess.RW_INTERLEAVED; //TODO: make that configurable or automatic
        int channels = 1; //TODO: make that configurable or automatic
        int rate = 8000; //TODO: make that configurable or automatic
        try
        {
            int transferBufferSize;

            this.frameSize = 2; //TODO: make that configurable or automatic

            //main Sound card
            assert( logger.debug( @"Setup alsa sink for modem audio" ) );
            this.codecPCM = new FsoAudio.PcmDevice();
            /* TODO: add an fso config for that (plug:dmix:0) */
            this.codecPCM.open( "plug:dmix:0", Alsa.PcmStream.PLAYBACK);
            this.codecPCM.setFormat( access, format, rate, channels );

            //modem sound card
            assert( logger.debug( @"Setup alsa source for modem audio" ) );
            this.modemPCM = new FsoAudio.PcmDevice();
            /* TODO: add an fso config for that (plug:dnoop:1) */
            this.modemPCM.open( "plug:dsnoop:1", Alsa.PcmStream.CAPTURE );
            this.modemPCM.setFormat( access, format, rate, channels );

            /* get the buffer parameters from the kernel */

            this.codecPCM.getParams( out this.codecBufferSize, out this.codecPeriodSize);
            assert ( logger.info( @"CODEC Buffer size is $((int)this.codecBufferSize), CODEC period size is $((int)this.codecPeriodSize)") );

            this.modemPCM.getParams( out this.modemBufferSize, out this.modemPeriodSize);
            assert ( logger.info( @"Modem Buffer size is $((int)this.modemBufferSize), Modem period size is $((int)this.modemPeriodSize)") );

            transferBufferSize = ((int)this.codecBufferSize > (int)this.modemBufferSize) ?
                (int)this.codecBufferSize : (int)this.modemBufferSize;

            assert ( logger.info( @"Buffer size is $(transferBufferSize)") );
            this.transferBuffer = new RingBuffer( transferBufferSize );
        }
        catch ( Error e )
        {
            logger.error( @"Error: $(e.message)" );
        }
    }

    private void playSilence( int frames )
    {
        Alsa.PcmSignedFrames ret;
        uint8[] silence_buffer = new uint8[ frames  * this.frameSize ];
        /* TODO: add a more configurable option for that */
        int retries = 3;

        while ( frames > 0 && retries > 0 )
        {
            try
            {
                ret = codecPCM.writei( silence_buffer, frames );
                if ( ret == -Posix.EPIPE )
                {
                    codecPCM.recover( -Posix.EPIPE, 0 );
                    retries--;
                }
                else
                {
                    frames--;
                }
            }
            catch ( FsoAudio.SoundError e )
            {
                logger.error( @"Silence  Error: $(e.message)" );
                return;
            }
        }
    }



    private void * recordThreadMethod()
    {
        Alsa.PcmSignedFrames frames;
        var buffer = new uint8[this.modemBufferSize];

        while ( this.runRecord > 0 )
        {
            transferBuffer.logInfos();
            try
            {
                frames = modemPCM.readi( buffer, this.modemPeriodSize );

                if ( frames == -Posix.EPIPE)
                {
                    modemPCM.prepare();
                }
                else
                {
                    if ( frames != this.modemPeriodSize)
                    {
                        stderr.printf("frames: %ld \n",(long)frames);
                    }

                    transferBuffer.write( buffer,(int)frames * this.frameSize );
                    this.conditionalWait.broadcast();
                }

            }
            catch ( FsoAudio.SoundError e )
            {
                logger.error( @"Record SoundError: $(e.message)" );
            }
            catch ( RingError e )
            {
                logger.warning( @"Record  RingBuffer error: $(e.message)" );
            }
        }
        return null;
    }

    private void * playbackThreadMethod()
    {
        Alsa.PcmSignedFrames frames;
        var buffer = new uint8[this.codecBufferSize];

        while (this.runPlayback > 0)
        {
            this.conditionalWait.wait(this.readyToRead);
            this.transferBuffer.logInfos();

            transferBuffer.logInfos();
            try
            {
                transferBuffer.read( buffer, (int)this.codecPeriodSize * this.frameSize );

                frames  = codecPCM.writei( buffer, this.codecPeriodSize);
                if ( frames == -Posix.EPIPE)
                {
                    codecPCM.recover ( -Posix.EPIPE,0);
                }else if ( frames != this.codecPeriodSize )
                {
                    stderr.printf("frames: %ld \n",(long)frames);
                }
            }
            catch ( FsoAudio.SoundError e )
            {
                logger.error( @"Playback Error: $(e.message)" );
            }
            catch ( RingError e )
            {
                logger.warning( @"Playback RingBuffer error: $(e.message)" );
                playSilence( 1 );
            }
        }
        return null;
    }

    private void startPlayback()
    {
        /* start the playback thread now
         */
        if ( !Thread.supported() )
        {
            logger.warning( "Cannot run without thread support!" );
        }
        else
        {
            if ( playbackThread == null )
            {
                try
                {
                    playbackThread = Thread.create<void *>( playbackThreadMethod, true );
                }
                catch ( ThreadError e )
                {
                    stdout.printf( @"Error: $(e.message)" );
                    return;
               }
            }
            else
            {
                stdout.printf( "Thread already launched \n" );
            }
            AtomicInt.set(ref runPlayback,1);
        }
    }

    private void startRecord()
    {
        /* start the record thread now */
        if ( !Thread.supported() )
        {
            logger.warning( "Cannot run without thread support!" );
        }
        else
        {
            if ( recordThread == null )
            {
                try
                {
                    recordThread = Thread.create<void *>( recordThreadMethod, true );
                }
                catch ( ThreadError e )
                {
                    stdout.printf( @"Error: $(e.message)" );
                    return;
               }
            }
            else
            {
                stdout.printf( "Thread already launched \n" );
            }
            AtomicInt.set(ref runRecord,1);
        }

    }




    private void stopPlayback()
    {
        AtomicInt.set(ref runPlayback,0);
        playbackThread.join();
        playbackThread = null;
        codecPCM.close();
        codecPCM  = null;
    }

    private void stopRecord()
    {
        AtomicInt.set(ref runRecord,0);
        recordThread.join();
        recordThread = null;
        modemPCM.close();
        modemPCM = null;
    }


    //
    // Public API
    //

    public override string repr()
    {
        return "<>";
    }

    public void setAudioStatus( bool enabled )
    {
        if ( enabled == this.status )
        {
            assert( logger.debug( @"Status already $status" ) );
            return;
        }
        assert( logger.debug( @"Setting call status to $enabled" ) );

        if ( enabled )
        {
             this.startRecord();
             this.startPlayback();
        }
        else
        {
            this.stopPlayback();
            this.stopRecord();
            transferBuffer.reset();
        }

        this.status = enabled;

    }



}

namespace FsoAudio.GsmVoiceForwarder
{
    public const string MODULE_NAME = "fsoaudio.gsmvoice_alsa_forwarder";
}

class FsoAudio.GsmVoiceForwarder.Plugin : FsoFramework.AbstractObject
{
    private FsoFramework.Subsystem subsystem;
    private FreeSmartphone.GSM.Call gsmcallproxy;
    /* TODO: configure the values */
    private PlaybackFromModem modemSourceCodecSink = new PlaybackFromModem();

    //
    // Private API
    //
    private void onCallStatusSignal( int id, FreeSmartphone.GSM.CallStatus status, GLib.HashTable<string,Variant> properties )
    {
        assert( logger.debug( @"onCallStatusSignal $id w/ status $status" ) );
        switch ( status )
        {
            case FreeSmartphone.GSM.CallStatus.OUTGOING:
            case FreeSmartphone.GSM.CallStatus.ACTIVE:
                this.modemSourceCodecSink.setAudioStatus(true);
                break;

            case FreeSmartphone.GSM.CallStatus.RELEASE:
                this.modemSourceCodecSink.setAudioStatus(false);
                break;

            default:
                assert( logger.debug( @"Unhandled call status $status" ) );
                break;
        }
    }

    //
    // Public API
    //
    public Plugin( FsoFramework.Subsystem subsystem )
    {
        this.subsystem = subsystem;

        try
        {
            gsmcallproxy = Bus.get_proxy_sync<FreeSmartphone.GSM.Call>( BusType.SYSTEM, "org.freesmartphone.ogsmd", "/org/freesmartphone/GSM/Device", DBusProxyFlags.DO_NOT_AUTO_START );
            gsmcallproxy.call_status.connect( onCallStatusSignal );
        }
        catch ( Error e )
        {
            logger.error( @"Could not hook to fsogsmd: $(e.message)" );
        }
    }

    public override string repr()
    {
        return "<>";
    }
}

internal FsoAudio.GsmVoiceForwarder.Plugin instance;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    instance = new FsoAudio.GsmVoiceForwarder.Plugin( subsystem );
    return FsoAudio.GsmVoiceForwarder.MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsoaudio.gsmvoice_alsa_forwarder fso_register_function" );
}
