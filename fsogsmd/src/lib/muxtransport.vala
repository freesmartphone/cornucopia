/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using GLib;

namespace FsoGsm
{
    public const int MUX_TRANSPORT_MAX_BUFFER = 1024;
}

//===========================================================================
public class FsoGsm.LibGsm0710muxTransport : FsoFramework.BaseTransport
//===========================================================================
{
    static Gsm0710mux.Manager manager;
    private Gsm0710mux.ChannelInfo channelinfo;
    private FsoFramework.DelegateTransport tdelegate;

    private char[] muxbuffer;
    private int length;

    private bool channelOpened;

    static construct
    {
        manager = new Gsm0710mux.Manager();
    }

    public LibGsm0710muxTransport( int channel = 0 )
    {
        base( "LibGsm0710muxTransport" );

        muxbuffer = new char[1024];
        length = 0;

        var version = manager.getVersion();
        var hasAutoSession = manager.hasAutoSession();
        assert( hasAutoSession ); // we do not support non-autosession yet

        tdelegate = new FsoFramework.DelegateTransport(
                                                      delegateWrite,
                                                      delegateRead,
                                                      delegateHup,
                                                      delegateOpen,
                                                      delegateClose,
                                                      delegateFreeze,
                                                      delegateThaw );

        channelinfo = new Gsm0710mux.ChannelInfo() {
            transport = tdelegate,
            number = channel,
            consumer = @"fsogsmd:$channel" };

        assert( logger.debug( @"Created. Using libgsm0710mux version $version; autosession is $hasAutoSession" ) );
    }

    public override string repr()
    {
        if ( channelinfo == null )
        {
            return "<0710:Unassigned>";
        }
        else
        {
            return @"<0710:$(channelinfo.number)>";
        }
    }

    public override bool open()
    {
        assert_not_reached(); // this transport can only be opened async
    }

    public override bool isOpen()
    {
        return channelOpened;
    }

    public override async bool openAsync()
    {
        try
        {
            yield manager.allocChannel( channelinfo );
        }
        catch ( Gsm0710mux.MuxerError e )
        {
            logger.error( @"Can't allocate channel #$(channelinfo.number) from MUX: $(e.message)" );
            return false;
        }
        channelOpened = true;
        return true;
    }

    public override int read( void* data, int length )
    {
        assert( this.length > 0 );
        assert( this.length < length );
        GLib.Memory.copy( data, this.muxbuffer, this.length );
#if DEBUG
        message( @"READ %d from MUX #$(channelinfo.number): %s", length, ((string)data).escape( "" ) );
#endif
        var l = this.length;
        this.length = 0;
        return l;
    }

    public override int write( void* data, int length )
    {
        assert( this.length == 0 ); // NOT REENTRANT!
        assert( length < MUX_TRANSPORT_MAX_BUFFER );
#if DEBUG
        message( @"WRITE %d to MUX #$(channelinfo.number): %s", length, ((string)data).escape( "" ) );
#endif
        this.length = length;
        GLib.Memory.copy( this.muxbuffer, data, length );
        tdelegate.readfunc( tdelegate );
        assert( this.length == 0 ); // everything has been consumed
        return length;
    }

    public override int freeze()
    {
        return -1; // we're not really freezing here
    }

    public override void thaw()
    {
    }

    public override void close()
    {
        if ( isOpen() )
        {
            try
            {
                manager.releaseChannel( channelinfo.consumer );
            }
            catch ( Gsm0710mux.MuxerError e )
            {
                logger.warning( @"Can't release channel #$(channelinfo.number) from MUX: $(e.message)" );
            }
            channelOpened = false;
        }
    }
    //
    // delegate transport interface
    //
    public bool delegateOpen( FsoFramework.Transport t )
    {
#if DEBUG
        message( "FROM MODEM OPEN ACK" );
#endif
        return true;
    }

    public void delegateClose( FsoFramework.Transport t )
    {
#if DEBUG
        message( "FROM MODEM CLOSE REQ" );
#endif
        if ( hupfunc != null )
        {
            this.hupfunc( this ); // signalize that the modem has forced us to close the channel
        }
        else
        {
            logger.error( "Unexpected CLOSE Request from modem received with no HUP func in place to notify upper layers" );
        }
    }

    public int delegateWrite( void* data, int length, FsoFramework.Transport t )
    {
        if ( pppOut == null )
        {
            assert( this.length == 0 );
#if DEBUG
            message( @"FROM MODEM #$(channelinfo.number) WRITE $length" );
#endif
            assert( length < MUX_TRANSPORT_MAX_BUFFER );
            GLib.Memory.copy( this.muxbuffer, data, length ); // prepare data
            this.length = length;
            this.readfunc( this ); // signalize data being available
            assert( this.length == 0 ); // all has been consumed
            return length;
        }
        else
        {
#if DEBUG
            message( @"FROM MODEM #$(channelinfo.number) FOR PPP WRITE $length" );
#endif
            var bwritten = Posix.write( pppInFd, data, length );
            assert( bwritten == length );
            return length;
        }
    }

    public int delegateRead( void* data, int length, FsoFramework.Transport t )
    {
        assert( this.length > 0 );
#if DEBUG
        message( @"FROM MODEM #$(channelinfo.number) READ $(this.length)" );
#endif
        assert( length > this.length );
        GLib.Memory.copy( data, this.muxbuffer, this.length );
        var l = this.length;
        this.length = 0;
        return l;
    }

    public void delegateHup( FsoFramework.Transport t )
    {
#if DEBUG
        message( "FROM MODEM HUP" );
#endif
    }

    public int delegateFreeze( FsoFramework.Transport t )
    {
#if DEBUG
        message( "FROM MODEM FREEZE REQ" );
#endif
        return -1;
    }

    public void delegateThaw( FsoFramework.Transport t )
    {
#if DEBUG
        message( "FROM MODEM THAW REQ" );
#endif
    }

    //
    // PPP forwarding
    //

    private int pppInFd;
    private FsoFramework.Async.ReactorChannel pppOut;

    public bool isForwardingToPPP()
    {
        return ( pppOut != null );
    }

    public void startForwardingToPPP( int infd, int outfd )
    {
        message( @"START FORWARDING TO PPP VIA $infd <--> $outfd" );
        if ( pppOut != null )
        {
            return;
        }
        pppInFd = infd;
        pppOut = new FsoFramework.Async.ReactorChannel( outfd, onDataFromPPP );
    }

    public void stopForwardingToPPP()
    {
        message( @"STOP FORWARDING TO PPP" );
        if ( pppOut == null )
        {
            return;
        }
        pppOut = null;
    }

    public void onDataFromPPP( void* data, ssize_t length )
    {
        if ( data == null && length == 0 )
        {
            message( "EOF FROM PPP" );
            return;
        }
#if DEBUG
        message( "ON DATA FROM PPP" );
#endif
        var bwritten = write( data, (int)length );
        assert( bwritten == length );
    }
}

// vim:ts=4:sw=4:expandtab
