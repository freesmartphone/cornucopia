/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

/**
 * @class AtSmsHandler
 **/
public class FsoGsm.AtSmsHandler : FsoGsm.AbstractSmsHandler
{
    //
    // protected
    //

    protected override async string retrieveImsiFromSIM()
    {
        var cimi = theModem.createAtCommand<PlusCIMI>( "+CIMI" );
        var response = yield theModem.processAtCommandAsync( cimi, cimi.execute() );
        if ( cimi.validate( response ) != Constants.AtResponse.VALID )
        {
            logger.warning( "Can't retrieve IMSI from SIM to be used as identifier for SMS storage" );
            return "";
        }
        return cimi.value;
    }

    protected override async void fetchMessagesFromSIM()
    {
        var cmgl = theModem.createAtCommand<PlusCMGL>( "+CMGL" );
        var cmglresponse = yield theModem.processAtCommandAsync( cmgl, cmgl.issue( PlusCMGL.Mode.ALL ) );
        if ( cmgl.validateMulti( cmglresponse ) != Constants.AtResponse.VALID )
        {
            logger.warning( "Could not fetch SMS messages from SIM card" );
            return;
        }

        var cmgd = theModem.createAtCommand<PlusCMGD>( "+CMGD" );
        foreach( var pdu in cmgl.hexpdus )
        {
            handleIncomingSms( pdu.hexpdu, pdu.tpdulen );
            var response = yield theModem.processAtCommandAsync( cmgd, cmgd.issue( pdu.transaction_index ) );
            if ( cmgd.validateOk( response ) != Constants.AtResponse.OK )
            {
                logger.error( @"Could not delete SMS with index $(pdu.transaction_index) from SIM" );
            }
        }
    }

    protected override async bool readSmsMessageFromSIM( uint index, out string hexpdu, out int tpdulen )
    {
        var cmd = theModem.createAtCommand<PlusCMGR>( "+CMGR" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.issue( index ) );
        if ( cmd.validateUrcPdu( response ) != Constants.AtResponse.VALID )
        {
            logger.warning( @"Can't read new SMS from SIM storage at index $index." );
            return false;
        }

        hexpdu = cmd.hexpdu;
        tpdulen = cmd.tpdulen;

        return true;
    }

    protected override async bool removeSmsMessageFromSIM( uint index )
    {
        var cmd = theModem.createAtCommand<PlusCMGD>( "+CMGD" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.issue( (int) index ) );
        if ( cmd.validateOk( response ) != Constants.AtResponse.OK )
        {
            logger.warning( @"Can't delete SMS message with index $index from SIM card." );
            return false;
        }

        return true;
    }

    protected override async bool acknowledgeSmsMessage( int id )
    {
        var cmd = theModem.createAtCommand<PlusCNMA>( "+CNMA" );
        var response = yield theModem.processAtCommandAsync( cmd, cmd.issue( 0 ) );
        if ( cmd.validate( response ) != Constants.AtResponse.VALID )
        {
            logger.warning( @"Can't acknowledge new SMS" );
            return false;
        }
        return true;
    }
}

// vim:ts=4:sw=4:expandtab
