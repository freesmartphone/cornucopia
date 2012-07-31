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
 **/

/**
 * @interface WatchDog
 **/
public interface FsoGsm.WatchDog : GLib.Object
{
    public abstract void check();
    public abstract void resetUnlockMarker();
}

/**
 * @class NullWatchDog
 **/

public class FsoGsm.NullWatchDog : GLib.Object, FsoGsm.WatchDog
{
    public void check()
    {
    }

    public void resetUnlockMarker()
    {
    }
}

/**
 * @class GenericWatchDog
 *
 **/
public class FsoGsm.GenericWatchDog : FsoGsm.WatchDog, FsoFramework.AbstractObject
{
    private bool unlockFailed;
    private bool inCampNetwork = false;

    private FsoGsm.Modem modem;

    public override string repr()
    {
        return @"<>";
    }

    private void onModemSimStatusChange( Modem.SimStatus status )
    {
        logger.debug( @"onModemSimStatusChange $status" );

        switch ( status )
        {
            case Modem.SimStatus.LOCKED:
                if ( modem.simAuthStatus() == FreeSmartphone.GSM.SIMAuthStatus.PIN_REQUIRED &&
                     modem.data().simPin != "" && !unlockFailed )
                {
                    unlockModem();
                }
                break;

            case Modem.SimStatus.READY:
                if ( modem.data().keepRegistration )
                    campNetwork();
                break;
        }
    }

    private void onModemNetworkStatusChange( Modem.NetworkStatus status )
    {
        logger.debug( @"onModemNetworkStatusChange $status" );

        switch ( status )
        {
            case Modem.NetworkStatus.REGISTERED:
                if ( modem.status() == Modem.Status.RESUMING )
                    triggerUpdateNetworkStatus( modem );
                break;

            default:
                break;
        }
    }

    private async void unlockModem()
    {
        try
        {
            var m = modem.createMediator<FsoGsm.SimSendAuthCode>();
            yield m.run( modem.data().simPin );
        }
        catch ( GLib.Error e1 )
        {
            logger.error( @"Could not unlock SIM PIN: $(e1.message)" );

            unlockFailed = true;

            try
            {
                // resend query to give us a proper PIN
                yield gatherSimStatusAndUpdate( modem );
            }
            catch ( GLib.Error e2 )
            {
                logger.error( @"Can't gather SIM status: $(e2.message)" );
            }
        }
    }

    private async void campNetwork()
    {
        if ( inCampNetwork )
            return;

        inCampNetwork = true;

        try
        {
            var m = modem.createMediator<FsoGsm.NetworkRegister>();
            yield m.run();
        }
        catch ( GLib.Error e )
        {
            logger.error( @"Could not register: $(e.message)" );
        }

        triggerUpdateNetworkStatus( modem );

        inCampNetwork = false;
    }

    //
    // public API
    //

    public GenericWatchDog( FsoGsm.Modem modem )
    {
        this.modem = modem;
        modem.signalSimStatusChanged.connect( onModemSimStatusChange );
        modem.signalNetworkStatusChanged.connect( onModemNetworkStatusChange );
    }

    public void check()
    {
        onModemSimStatusChange( modem.simStatus() );
        onModemNetworkStatusChange( modem.networkStatus() );
    }

    public void resetUnlockMarker()
    {
        unlockFailed = false;
    }
}

// vim:ts=4:sw=4:expandtab
