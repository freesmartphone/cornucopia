/*
 * Copyright (C) 2012 Lukas 'Slyon' Märdian <lukasmaerdian@gmail.com>
 *               2012 Simon Busch <morphis@gravedo.de>
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

class LowLevel.Neo900 : FsoGsm.LowLevel, FsoFramework.AbstractObject
{
    public const string MODULE_NAME = "fsogsm.lowlevel_neo900";
    private string modem_node;
    private bool skip_shutdown;

    construct
    {
        modem_node = config.stringValue( MODULE_NAME, "modem_node", "/dev/ttyUSB2" );
        skip_shutdown = config.boolValue( MODULE_NAME, "skip_shutdown", false );
        logger.info( "Registering neo900 low level modem toggle" );
    }

    public override string repr()
    {
        return "<>";
    }

    public bool is_powered()
    {
        return FsoFramework.FileHandling.isPresent( modem_node );
    }

    private bool toggle_modem_power_state( bool desired_power_state)
    {
        // TODO: power up/down the modem via proper GPIO once the prototype is there
        // for now we have to rely on manual press of power button

        var retries = 0;
        while ( retries < 5 )
        {
            assert( logger.debug( "Checking if modem is powered %s ...".printf( desired_power_state ? "on" : "off" ) ) );

            if ( ( desired_power_state && FsoFramework.FileHandling.isPresent( modem_node ) ) ||
                 ( !desired_power_state  && !FsoFramework.FileHandling.isPresent( modem_node ) ) )
                break;

            if (!desired_power_state ) break;

            Posix.sleep( 2 );

            retries++;
        }

        return retries < 5;
    }

    /**
     * Power on the modem. After calling this the modem is ready to use.
     * NOTE: Calling poweron() will probably block for some seconds until the
     * modem is completely initialized.
     **/
    public bool poweron()
    {
        if ( !poweroff() )
        {
            assert( logger.debug( @"Modem already active, could not power off!" ) );
            return false;
        }

        assert( logger.debug( @"Powering modem on now ..." ) );
        return toggle_modem_power_state( true );
    }

    /**
     * Powering off the modem.
     * NOTE: Calling poweroff() will probably block for some seconds until the
     * modem is completely powered off.
     **/
    public bool poweroff()
    {
        if ( !is_powered() )
        {
            assert( logger.debug( @"Skipping poweroff as modem is already not powered" ) );
            return true;
        }
        if ( skip_shutdown )
        {
            assert( logger.info( @"Skipping poweroff as requested in config" ) );
            return true;
        }
        return toggle_modem_power_state( false );
    }

    /**
     * Suspend the modem - UNIMPLEMENTED
     **/
    public bool suspend()
    {
        return true;
    }

    /**
     * Resume the modem - UNIMPLEMENTED
     **/
    public bool resume()
    {
        return true;
    }
}

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    FsoFramework.theLogger.debug( "lowlevel_neo900 fso_factory_function" );
    return LowLevel.Neo900.MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    // do not remove this function
}

// vim:ts=4:sw=4:expandtab
