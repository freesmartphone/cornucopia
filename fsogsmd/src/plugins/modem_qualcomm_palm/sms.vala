/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *                         Simon Busch <morphis@gravedo.de>
 *                         Lukas Märdian <lukasmaerdian@gmail.com>
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

using Gee;
using FsoGsm;

/**
 * @class MsmSmsHandler
 **/
public class MsmSmsHandler : FsoGsm.AbstractSmsHandler
{
    protected override async string retrieveImsiFromSIM()
    {
        var channel = theModem.channel( "main" ) as MsmChannel;
        string imsi = "unknown";

        try
        {
            var sim_field_info = yield channel.sim_service.read_field( Msmcomm.SimFieldType.IMSI );
            imsi = sim_field_info.data;
        }
        catch ( GLib.Error err )
        {
            logger.error( @"Could not gather IMSI number, got: $(err.message)" );
        }

        return imsi;
    }

    protected override async void fetchMessagesFromSIM()
    {
    }

    protected override async bool readSmsMessageFromSIM( uint index, out string hexpdu, out int tpdulen )
    {
        return true;
    }

    protected override async bool removeSmsMessageFromSIM( uint index )
    {
        return true;
    }

    protected override async bool acknowledgeSmsMessage( string hexpdu, int tpdulen )
    {
        bool result = true;
        var channel = theModem.channel( "main" ) as MsmChannel;

        try
        {
            yield channel.sms_service.acknowledge_message();
            logger.info( @"Acknowledged new SMS" );
        }
        catch ( GLib.Error err )
        {
            logger.error( @"Can't acknowledge new SMS, got: $(err.message)" );
            result = false;
        }

        return result;
    }
}

// vim:ts=4:sw=4:expandtab
