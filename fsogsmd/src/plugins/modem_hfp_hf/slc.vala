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
using FsoGsm.Constants;

public class HfpHf.ServiceLevelConnection : FsoFramework.AbstractObject
{
    private FsoGsm.Modem _modem;
    private int _version;

    public enum Status
    {
        CLOSED,
        INITIALIZING,
        ACTIVE,
    }

    public Status status { get; private set; default = Status.CLOSED; }
    public int supported_features_hf { get; private set; default = 0; }
    public int supported_features_ag { get; private set; default = 0; }
    public int[] supported_features_ag_mpty { get; private set; default = { }; }

    //
    // public API
    //

    public ServiceLevelConnection( FsoGsm.Modem modem, int version )
    {
        _modem = modem;
        _version = version;

        supported_features_ag = 0;
        supported_features_hf = Bluetooth.HFP.Feature.HF_3WAY |
                                 Bluetooth.HFP.Feature.HF_CLIP |
                                 Bluetooth.HFP.Feature.HF_REMOTE_VOLUME_CONTROL;

        if ( version >= Bluetooth.HFP.Version.VERSION_1_5 )
        {
            supported_features_hf |= Bluetooth.HFP.Feature.HF_ENHANCED_CALL_STATUS |
                                      Bluetooth.HFP.Feature.HF_ENHANCED_CALL_CONTROL;
        }
    }

    /**
     * See Bluetooth HFP 1.6 spec chapter 4.2.1 on page 17 for more details.
     **/
    public async bool initialize( Indicators indicators )
    {
        string[] response = { };

        if ( status == Status.INITIALIZING || status == Status.ACTIVE )
            return true;

        status = Status.INITIALIZING;

        try
        {
            var channel = _modem.channel( "main" ) as AtCommandQueue;

            // tell AG about our supported features and retrieve its supported features
            var cmd_brsf = _modem.createAtCommand<PlusBRSF>( "+BRSF" ) as PlusBRSF;
            response = yield channel.enqueueAsync( cmd_brsf, cmd_brsf.issue( supported_features_hf ) );
            checkResponseValid( cmd_brsf, response );
            supported_features_ag = cmd_brsf.value;

            // retrieve supported indicators
            var cmd_cind = _modem.createAtCommand<PlusCIND>( "+CIND" ) as PlusCIND;
            response = yield channel.enqueueAsync( cmd_cind, cmd_cind.test() );
            checkTestResponseValid( cmd_cind, response );

            // retrieve status of the indicators
            var cmd_cind2 = _modem.createAtCommand<PlusCIND>( "+CIND" ) as PlusCIND;
            response = yield channel.enqueueAsync( cmd_cind2, cmd_cind2.query() );
            checkResponseValid( cmd_cind2, response );

            for ( var n = 0; n < cmd_cind.indicators.length; n++ )
            {
                var type = Constants.indicator_from_string( cmd_cind.indicators[n] );
                indicators.set_index( type, n );
                indicators.update( type, cmd_cind2.status[n] );
            }

            var cmd_cmer = _modem.createAtCommand<PlusCMER>( "+CMER" ) as PlusCMER;
            response = yield channel.enqueueAsync( cmd_cmer, cmd_cmer.issue( 3, 0, 0, 1, 0 ) );
            checkResponseOk( cmd_cmer, response );

            var cmd_cmee = _modem.createAtCommand<PlusCMEE>( "+CMEE" ) as PlusCMEE;
            response = yield channel.enqueueAsync( cmd_cmee, cmd_cmee.issue( 1 ) );
            checkResponseOk( cmd_cmee, response );

            if ( ( supported_features_ag & Bluetooth.HFP.Feature.AG_3WAY ) == Bluetooth.HFP.Feature.AG_3WAY )
            {
                var cmd_chld = _modem.createAtCommand<PlusCHLD>( "+CHLD" ) as PlusCHLD;
                response = yield channel.enqueueAsync( cmd_chld, cmd_chld.test() );
                checkTestResponseValid( cmd_chld, response );
                supported_features_ag_mpty = cmd_chld.features;
            }

            assert( logger.debug( @"Service level connection established" ) );
        }
        catch ( GLib.Error e )
        {
            logger.error( @"Failed to establish service level connection" );
            status = Status.CLOSED;
            return false;
        }

        status = Status.ACTIVE;

        return true;
    }

    public async void release()
    {
        status = Status.CLOSED;
    }

    public override string repr()
    {
        return @"<>";
    }
}

// vim:ts=4:sw=4:expandtab
