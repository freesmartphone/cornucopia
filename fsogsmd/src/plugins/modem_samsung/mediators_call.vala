/*
 * Copyright (C) 2011 Simon Busch <morphis@gravedo.de>
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

using FsoGsm;
using FsoFramework;
using FsoFramework.Utility;

public class SamsungCallActivate : CallActivate
{
    public override async void run( int id ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        yield theModem.callhandler.activate( id );
    }
}

public class SamsungCallHoldActive : CallHoldActive
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        yield theModem.callhandler.hold();
    }
}

public class SamsungCallInitiate : CallInitiate
{
    public override async void run( string number, string ctype ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        validatePhoneNumber( number );
        id = yield theModem.callhandler.initiate( number, ctype );
    }
}

public class SamsungCallListCalls : CallListCalls
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        var channel = theModem.channel( "main" ) as Samsung.IpcChannel;
        unowned SamsungIpc.Response? response = null;
        var callList = new GLib.List<FreeSmartphone.GSM.CallDetail?>();

        response = yield channel.enqueue_async( SamsungIpc.RequestType.GET, SamsungIpc.MessageType.CALL_LIST );

        if ( response == null )
            throw new FreeSmartphone.Error.INTERNAL_ERROR( @"Modem didn't respond current call list!" );

        unowned SamsungIpc.Call.ListResponseMessage callListResponse = (SamsungIpc.Call.ListResponseMessage) response;
        var numberOfCalls = callListResponse.get_num_entries();
        assert( theLogger.debug( @"We have totally a number of $(numberOfCalls) calls pending" ) );

        for ( var n = 0; n < numberOfCalls; n++ )
        {
            var currentCallEntry = callListResponse.get_entry( n );

            // We're not interested in DATA calls here as we do only VOICE call processing!
            if ( currentCallEntry.type == SamsungIpc.Call.Type.DATA )
                continue;

            var ci = FreeSmartphone.GSM.CallDetail(
                currentCallEntry.idx,
                Constants.instance().callStatusToEnum( (int) currentCallEntry.state ),
                new GLib.HashTable<string,Variant>( str_hash, str_equal )
            );

            string number = callListResponse.get_entry_number( n );
            if ( number != null )
                ci.properties.insert( "peer", number);

            callList.append( ci );
        }

        calls = listToArray<FreeSmartphone.GSM.CallDetail?>( callList );
    }
}

public class SamsungCallSendDtmf : CallSendDtmf
{
    public override async void run( string tones ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        throw new FreeSmartphone.Error.UNSUPPORTED( "Not implemented yet!" );
    }
}

public class SamsungCallRelease : CallRelease
{
    public override async void run( int id ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        yield theModem.callhandler.release( id );
    }
}

public class SamsungCallReleaseAll : CallReleaseAll
{
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        yield theModem.callhandler.releaseAll();
    }
}

// vim:ts=4:sw=4:expandtab