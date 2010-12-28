/*
 * Copyright (C) 2010 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

namespace NokiaIsi
{

/*
 * org.freesmartphone.Info
 */
public class IsiDeviceGetInformation : DeviceGetInformation
{
    /* revision, model, manufacturer, imei */

    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        info = new GLib.HashTable<string,Variant>( str_hash, str_equal );

        NokiaIsi.modem.isidevice.query_manufacturer( ( error, msg ) => {
            info.insert( "manufacturer", error ? "unknown" : msg );
            run.callback();
        } );
        yield;

        NokiaIsi.modem.isidevice.query_model( ( error, msg ) => {
            info.insert( "model", error ? "unknown" : msg );
            run.callback();
        } );
        yield;

        NokiaIsi.modem.isidevice.query_revision( ( error, msg ) => {
            info.insert( "revision", error ? "unknown" : msg );
            run.callback();
        } );
        yield;

        NokiaIsi.modem.isidevice.query_serial( ( error, msg ) => {
            info.insert( "imei", error ? "unknown" : msg );
            run.callback();
        } );
        yield;
    }
}

/*
 * org.freesmartphone.GSM.SIM
 */
public class IsiSimGetAuthStatus : SimGetAuthStatus
{
    // public FreeSmartphone.GSM.SIMAuthStatus status;
    public override async void run() throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
    {
        ISI.SIMAuth.status isicode = 0;

        NokiaIsi.modem.isisimauth.request_status( ( code ) => {
            isicode = code;
            run.callback();
        } );
        yield;

        switch ( isicode )
        {
			case ISI.SIMAuth.status.NO_SIM:
                throw new FreeSmartphone.GSM.Error.SIM_NOT_PRESENT( "No SIM" );
                break;
			case ISI.SIMAuth.status.NEED_NONE:
                status = FreeSmartphone.GSM.SIMAuthStatus.READY;
                break;
			case ISI.SIMAuth.status.NEED_PIN:
                status = FreeSmartphone.GSM.SIMAuthStatus.PIN_REQUIRED;
                break;
			case ISI.SIMAuth.status.NEED_PUK:
                status = FreeSmartphone.GSM.SIMAuthStatus.PUK_REQUIRED;
                break;
            default:
                status = FreeSmartphone.GSM.SIMAuthStatus.UNKNOWN;
                break;
        }
    }
}

/*
 * Register Mediators
 */
static void registerMediators( HashMap<Type,Type> mediators )
{
    mediators[ typeof(DeviceGetInformation) ]            = typeof( IsiDeviceGetInformation );
    mediators[ typeof(SimGetAuthStatus) ]                = typeof( IsiSimGetAuthStatus );

    theModem.logger.debug( "Nokia ISI mediators registered" );
}

} /* namespace NokiaIsi */
