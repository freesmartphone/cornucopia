/*
 * Copyright (C) 2012 Simon Busch
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
using FsoGsm;

public class HfpHf.AtChannel : FsoGsm.AtCommandQueue, FsoGsm.Channel
{
    protected string name;
    private bool initialized;
    private FsoGsm.Modem modem;
    private ServiceLevelConnection slc;
    private int supported_features;
    private int version;

    public AtChannel( FsoGsm.Modem modem, string? name, FsoFramework.Transport transport, FsoFramework.Parser parser, int version )
    {
        base( transport, parser );

        this.name = name;
        this.modem = modem;
        this.version = version;
        // FIXME providing both modem and channel to the slc is rather unpleasant ...
        this.slc = new ServiceLevelConnection( modem, this, version );

        modem.registerChannel( name, this );
        modem.signalStatusChanged.connect( onModemStatusChanged );

        assert( modem.logger.debug( @"Created AT channel for HFP version 0x%04x".printf( version ) ) );
    }

    public void onModemStatusChanged( FsoGsm.Modem modem, FsoGsm.Modem.Status status )
    {
        switch ( status )
        {
            case FsoGsm.Modem.Status.INITIALIZING:
                initialize();
                break;
            case FsoGsm.Modem.Status.CLOSING:
                shutdown();
                break;
            default:
                break;
        }
    }

    private async void initialize()
    {
        assert( modem.logger.debug( @"Initializing channel $name ..." ) );

        var result = yield slc.initialize();

        this.initialized = true;
    }

    private async void shutdown()
    {
        assert( modem.logger.debug( @"Shutting down channel $name ..." ) );

        var result = yield slc.release();
    }

    public void injectResponse( string response )
    {
        parser.feed( response, (int)response.length );
    }

    public async bool suspend()
    {
        return true;
    }

    public async bool resume()
    {
        return true;
    }
}

// vim:ts=4:sw=4:expandtab
