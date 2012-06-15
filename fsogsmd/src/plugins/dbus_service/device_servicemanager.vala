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

using GLib;

public class FsoGsm.DeviceServiceManager : FsoGsm.ServiceManager
{
    public FsoGsm.Modem modem { get; private set; }

    public bool initialized { get; private set; default = false; }

    //
    // private
    //

    private void onModemHangup()
    {
        logger.warning( "Modem no longer responding; trying to reopen in 5 seconds" );
        Timeout.add_seconds( 5, () => {
            onModemHangupAsync();
            return false;
        } );
    }

    private async void onModemHangupAsync()
    {
        var ok = yield enable();
        if ( !ok )
        {
            onModemHangup();
        }
    }

    //
    // public API
    //

    public DeviceServiceManager( int num, FsoGsm.Modem modem, FsoFramework.Subsystem subsystem )
    {
        var path = "%s/%i".printf( FsoFramework.GSM.DeviceServicePath, num );
        base( subsystem, FsoFramework.GSM.ServiceDBusName, path );

        registerService<FreeSmartphone.Info>( new FsoGsm.InfoService() );
        registerService<FreeSmartphone.Device.RealtimeClock>( new FsoGsm.DeviceRtcService() );
        registerService<FreeSmartphone.Device.PowerSupply>( new FsoGsm.DevicePowerSupplyService() );
        registerService<FreeSmartphone.GSM.Device>( new FsoGsm.GsmDeviceService() );
        registerService<FreeSmartphone.GSM.Debug>( new FsoGsm.GsmDebugService() );
        registerService<FreeSmartphone.GSM.Call>(new FsoGsm.GsmCallService() );
        registerService<FreeSmartphone.GSM.CallForwarding>( new FsoGsm.GsmCallForwardingService() );
        registerService<FreeSmartphone.GSM.CB>( new FsoGsm.GsmCbService() );
        registerService<FreeSmartphone.GSM.HZ>( new FsoGsm.GsmHzService() );
        registerService<FreeSmartphone.GSM.Monitor>( new FsoGsm.GsmMonitorService() );
        registerService<FreeSmartphone.GSM.Network>( new FsoGsm.GsmNetworkService() );
        registerService<FreeSmartphone.GSM.PDP>( new FsoGsm.GsmPdpService() );
        registerService<FreeSmartphone.GSM.SIM>( new FsoGsm.GsmSimService() );
        registerService<FreeSmartphone.GSM.SMS>( new FsoGsm.GsmSmsService() );
        registerService<FreeSmartphone.GSM.VoiceMail>( new FsoGsm.GsmVoiceMailService() );

        this.modem = modem;
        modem.parent = this;
        modem.hangup.connect( onModemHangup );
        this.assignModem( modem );

        initialized = true;

        var modemtype = FsoFramework.theConfig.stringValue( "fsogsm", "modem_type", "none" );
        logger.info( @"Ready. Configured for modem $modemtype" );
    }

    public void unregister_services()
    {
        unregisterService<FreeSmartphone.Info>();
        unregisterService<FreeSmartphone.Device.RealtimeClock>();
        unregisterService<FreeSmartphone.Device.PowerSupply>();
        unregisterService<FreeSmartphone.GSM.Device>();
        unregisterService<FreeSmartphone.GSM.Debug>();
        unregisterService<FreeSmartphone.GSM.Call>();
        unregisterService<FreeSmartphone.GSM.CallForwarding>();
        unregisterService<FreeSmartphone.GSM.CB>();
        unregisterService<FreeSmartphone.GSM.HZ>();
        unregisterService<FreeSmartphone.GSM.Monitor>();
        unregisterService<FreeSmartphone.GSM.Network>();
        unregisterService<FreeSmartphone.GSM.PDP>();
        unregisterService<FreeSmartphone.GSM.SIM>();
        unregisterService<FreeSmartphone.GSM.SMS>();
        unregisterService<FreeSmartphone.GSM.VoiceMail>();
    }

    public override async bool enable()
    {
        var ok = yield modem.open();
        if ( !ok )
        {
            logger.error( "Can't open modem" );
            return false;
        }
        else
        {
            logger.info( "Modem opened successfully" );
            state = ServiceState.ENABLED;
            return true;
        }
    }

    public override async void disable()
    {
        yield modem.close();
        logger.info( "Modem closed successfully" );
        state = ServiceState.DISABLED;
    }

    public override async void suspend()
    {
        var ok = yield modem.suspend();
        if ( ok )
        {
            logger.info( "Modem suspended successfully" );
            state = ServiceState.SUSPENDED;
        }
        else
        {
            logger.warning( "Modem not suspended; prepare yourself for spurious wakeups" );
        }
    }

    public override async void resume()
    {
        var ok = yield modem.resume();
        if ( ok )
        {
            logger.info( "Modem resumed successfully" );
            state = ServiceState.ENABLED;
        }
        else
        {
            logger.warning( "Modem did not resume correctly" );
        }
    }
}

// vim:ts=4:sw=4:expandtab
