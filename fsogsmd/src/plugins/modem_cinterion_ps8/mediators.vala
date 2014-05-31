/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2014 Sebastian Krzyszkowiak <dos@dosowisko.net>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using FsoGsm;
using Gee;

namespace CinterionPS8 {

    /**
     * +VTS: DTMF and tone generationm
     * PS8 requires the argument to be enclosed in quotation marks.
     **/
    public class CinterionCallSendDtmf : AtCallSendDtmf
    {
        public override async void run( string tones ) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
        {
            var cmd = modem.createAtCommand<CinterionPlusVTS>( "+VTS" );
            var response = yield modem.processAtCommandAsync( cmd, cmd.issue( tones ) );
            checkResponseOk( cmd, response );
        }
    }

    /**
    * +CREG doesn't work when in airplane mode, so call it right after +CFUN=1
    **/
    public class CinterionDeviceSetFunctionality : AtDeviceSetFunctionality
    {
        public override async void run(string level, bool autoregister, string pin) throws FreeSmartphone.GSM.Error, FreeSmartphone.Error
        {
            yield base.run(level, autoregister, pin);
            if (level == "full")
            {
                modem.logger.debug("Issuing +CREG=2 after setting +CFUN=1...");
                var regCmd = modem.createAtCommand<PlusCREG>( "+CREG" );
                var queryanswer = yield modem.processAtCommandAsync( regCmd, regCmd.issue(PlusCREG.Mode.ENABLE_WITH_NETWORK_REGISTRATION_AND_LOCATION) );
                if ( regCmd.validateOk( queryanswer ) != Constants.AtResponse.OK )
                {
                    modem.logger.error( "Failed to setup network registration reporting; reports will not be available ..." );
                }
            }
        }
    }

    /**
    * Register all mediators
    **/
    public void registerCustomMediators( HashMap<Type,Type> table )
    {
        table[ typeof(CallSendDtmf) ]                   = typeof( CinterionCallSendDtmf );
        table[ typeof(DeviceSetFunctionality) ]         = typeof( CinterionDeviceSetFunctionality );
    }

} /* CinterionPS8 */

// vim:ts=4:sw=4:expandtab
