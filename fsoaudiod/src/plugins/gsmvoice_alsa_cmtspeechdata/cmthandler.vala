/*
 * Copyright (C) 2011-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *                         Denis 'GNUtoo' Carikli <GNUtoo@no-log.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
CmtSpeech.Connection connection;
DataOutputStream output;
public bool status = false;

struct Buffer {
    public uint8[] content;
    public long length;
}

struct PCM {
	int channels;
	int rate;
	Alsa.PcmAccess access;
	Alsa.PcmFormat format;
	FsoAudio.PcmDevice device;
}

PCM PCMout;

/**
 * @class CmtHandler
 *
 * Handles Audio via libcmtspeechdata
 **/
public class CmtHandler : FsoFramework.AbstractObject
{
//	UnixInputStream channel;
	int fd;

    //
    // Constructor
    //
    public CmtHandler()
    {
        CmtSpeech.init();
        //CmtSpeech.trace_toggle( CmtSpeech.TraceType.STATE_CHANGE, true );
        //CmtSpeech.trace_toggle( CmtSpeech.TraceType.IO, true );
        //CmtSpeech.trace_toggle( CmtSpeech.TraceType.DEBUG, true );
        connection = new CmtSpeech.Connection();
        if ( connection == null )
        {
            logger.error( "Can't instanciate connection" );
            return;
        }

        fd = connection.descriptor();

        if ( fd == -1 )
        {
            error( "Cmtspeech file descriptor invalid" );
        }
		
//		channel = new UnixInputStream(fd,true);
		try{
			unowned Thread<void*> cmtspeech_loop =  Thread.create<void*>(read_from_modem_and_write_to_file,true);
		}catch (ThreadError e){
			stderr.printf(e.message);
		}
		
		// try{
		// 	//	Thread.create(read_from_modem_and_write_to_file,true);

		// }catch(ThreadError e){
		// 	stderr.printf(e.message);
		// }
    }

	private void setup_file_sink(string filepath)
	{
		try{
			PCMout = PCM();
			PCMout.rate = 8000;
			PCMout.channels = 1;
			PCMout.device = new FsoAudio.PcmDevice();
			PCMout.access = Alsa.PcmAccess.RW_INTERLEAVED;
			PCMout.format = Alsa.PcmFormat.S16_LE;
			PCMout.device.open("plug:dmix");
			PCMout.device.setFormat( PCMout.access, PCMout.format, PCMout.rate, PCMout.channels );
		}catch (Error e)
		{
			stderr.printf(@"Error: $(e.message)");
		}


        // var file = File.new_for_path (filepath);
        // if (file.query_exists ())
        // {
        //     try
        //     {
        //         file.delete ();
        //     }
        //     catch (GLib.Error e)
        //     {
        //         logger.error( @"Could not delete existing file: $(e.message)" );
        //     }
        // }
        // try
        // {
        //     output = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));
        // }
        // catch (GLib.Error e)
        // {
        //      logger.error( @"Could not create file: $(e.message)" );
        // }
		// return file;
	}
	
	void* read_from_modem_and_write_to_file () {
		int errnum;
		Posix.pollfd fds[1];
		fds[0] = Posix.pollfd();
		fds[0].fd = this.fd;
		fds[0].events = (IOCondition.IN | IOCondition.HUP);

		/* set realtime running not to miss buffers. */
		Posix.Sched.Param param = { 99 }; /* 1(low priority) to 99(higher priority)*/
		int realtime = Posix.Sched.setscheduler(0, Posix.Sched.Algorithm.FIFO, ref param);
		errnum = Posix.errno;
		if (realtime !=0){
			stderr.printf(@"ERROR: $(errnum) not realtime\n");
		}
		while (true) {
			Buffer? buffer = null;
			Posix.poll(fds,500000);
			if (!onInputFromChannel (out buffer)) {
				break;
			}
			if (buffer != null)
				writeToFile(buffer);
		}
		return null;
	}

    private static async void  writeToFile(Buffer buffer)
    {
            long frames = 0;
			/*TODO: autodetect the divider*/
			try
			{
				frames = PCMout.device.writei( (uint8[])buffer.content,buffer.length / 2 );
			}
			catch(FsoAudio.SoundError e)
			{
				stderr.printf(e.message);
			}
            // while (written < buffer.length ) {
            //     try
            //     {
            //         written += yield output.write_async((uint8[])buffer.content[written:buffer.length], Priority.DEFAULT, null);
            //     }
            //     catch (GLib.IOError e)
            //     {
            //         stderr.printf( @"Could not write to file: $(e.message)\n" );
            //     }
            // }

			// while (written < buffer.length ) {
            //     try
            //     {
            //         written += yield output.write_async((uint8[])buffer.content[written:buffer.length], Priority.DEFAULT, null);
            //     }
            //     catch (GLib.IOError e)
            //     {
            //         stderr.printf( @"Could not write to file: $(e.message)\n" );
            //     }
            // }
    }

    private static void handleDataEvent(out Buffer buffer)
    {
        debug( @"handleDataEvent during protocol state $(connection.protocol_state())" );

        CmtSpeech.FrameBuffer dlbuf = null;
        CmtSpeech.FrameBuffer ulbuf = null;
        buffer = Buffer();

        var ok = connection.dl_buffer_acquire( out dlbuf );
        if ( ok == 0 )
        {
            debug( "received DL packet w/ %u bytes", dlbuf.count );
            if ( connection.protocol_state() == CmtSpeech.State.ACTIVE_DLUL )
            {
               debug( "protocol state is ACTIVE_DLUL, uploading as well..." );
                ok = connection.ul_buffer_acquire( out ulbuf );
                if ( ulbuf.pcount == dlbuf.pcount )
                {
                    debug( "looping DL packet to UL with %u payload bytes", dlbuf.pcount );
                    buffer.content  = new uint8[dlbuf.pcount];
                    buffer.length = dlbuf.pcount;
                    Memory.copy( buffer.content, dlbuf.payload, dlbuf.pcount );
                }
                connection.ul_buffer_release( ulbuf );
            }
            connection.dl_buffer_release( dlbuf );
        }
    }

    private static void handleControlEvent()
    {
        debug( @"handleControlEvent during protocol state $(connection.protocol_state())" );

        CmtSpeech.Event event = CmtSpeech.Event();
        CmtSpeech.Transition transition = 0;

        connection.read_event( ref event );

        debug( @"read event, type is $(event.msg_type)" );
        transition = connection.event_to_state_transition( event );

        switch( transition )
        {
            case CmtSpeech.Transition.INVALID:
              debug( "ERROR: invalid state transition");
              break;

            case CmtSpeech.Transition.1_CONNECTED:
            case CmtSpeech.Transition.2_DISCONNECTED:
            case CmtSpeech.Transition.3_DL_START:
            case CmtSpeech.Transition.4_DLUL_STOP:
            case CmtSpeech.Transition.5_PARAM_UPDATE:
              debug( @"state transition ok, new state is $transition" );
              break;

            case CmtSpeech.Transition.6_TIMING_UPDATE:
            case CmtSpeech.Transition.7_TIMING_UPDATE:
              debug( "WARNING: modem UL timing update ignored" );
              break;

            case CmtSpeech.Transition.10_RESET:
            case CmtSpeech.Transition.11_UL_STOP:
            case CmtSpeech.Transition.12_UL_START:
              debug( @"state transition ok, new state is $transition" );
              break;

            default:
              assert_not_reached();
        }
    }

    //===========================================================================
    private static bool onInputFromChannel(out Buffer buffer)
    {
        CmtSpeech.EventType flags = 0;
        var ok = connection.check_pending( out flags );
        if (ok > 0)
		{
            debug( "connection reports pending events with flags 0x%0X", flags );

            if ( ( flags & CmtSpeech.EventType.DL_DATA ) == CmtSpeech.EventType.DL_DATA )
            {
                handleDataEvent(out buffer);
            }
            else if ( ( flags & CmtSpeech.EventType.CONTROL ) == CmtSpeech.EventType.CONTROL )
            {
                handleControlEvent();
            }
            else
            {
                debug( "event no DL_DATA nor CONTROL, ignoring" );
            }
        }
        else if ( ok < 0 )
        {
            debug( "error while checking for pending events..." );
        }
        else if ( ok == 0 )
        {
            debug( "D'oh, cmt speech readable, but no events pending..." );
        }
        return true;
    }

    //
    // Public API
    //

    public override string repr()
    {
        CmtSpeech.State state = ( connection != null ) ? connection.protocol_state() : 0;
        return @"<$state>";
    }

    public void setAudioStatus( bool enabled )
    {
        if ( enabled == status )
        {
            debug( @"Status already $status");
            return;
        }

		if (enabled)
			setup_file_sink("/home/root/out.wav");

        debug( @"Setting call status to $enabled");
        connection.state_change_call_status( enabled );
        status = enabled;
    }

} /* End CmtHandler */

// vim:ts=4:sw=4:expandtab
