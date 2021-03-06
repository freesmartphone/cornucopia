/*
 * Copyright (C) 2011-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using GLib;

namespace Manager { const string MODULE_NAME = "fsophone.manager"; }

class Phone.Manager : FsoFramework.AbstractObject
{
    private FsoFramework.Subsystem subsystem;
    private FsoPhone.ICommunicationProvider[] plugins;

    public Manager( FsoFramework.Subsystem subsystem )
    {
        this.subsystem = subsystem;
        //subsystem.registerObjectForService<FreeSmartphone.Data.World>( FsoFramework.Data.ServiceDBusName, FsoFramework.Data.WorldServicePath, this );
        logger.info( @"Created" );

        Idle.add( () => {
            registerProviderPlugins();
            probe();
            return false;
        } );
    }

    public override string repr()
    {
        return "<>";
    }

    //
    // private API
    //
    private void registerProviderPlugins()
    {
        plugins = new FsoPhone.ICommunicationProvider[] {};

        var children = typeof( FsoFramework.AbstractObject ).children();
        foreach ( var child in children )
        {
            if ( child.is_a( typeof( FsoPhone.ICommunicationProvider ) ) )
            {
                var obj = Object.new( child );
                if ( obj != null )
                {
                    plugins += (FsoPhone.ICommunicationProvider) obj;
                }
                else
                {
                    logger.error( @"Can't instantiate $(child.name())" );
                }
            }
        }

        logger.info( @"Instantiated $(plugins.length) communication providers" );
    }

    private async void probe()
    {
        foreach ( var provider in plugins )
        {
            yield provider.probe();
        }
    }

    //
    // DBus API (org.freesmartphone.Phone.Manager)
    //
}

internal Phone.Manager instance;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    instance = new Phone.Manager( subsystem );
    return Manager.MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsophone.manager fso_register_function" );
}

/**
 * This function gets called on plugin load time.
 * @return false, if the plugin operating conditions are present.
 * @note Some versions of glib contain a bug that leads to a SIGSEGV
 * in g_module_open, if you return true here.
 **/
/*public static bool g_module_check_init( void* m )
{
    var ok = FsoFramework.FileHandling.isPresent( Kernel26.SYS_CLASS_LEDS );
    return (!ok);
}
*/

// vim:ts=4:sw=4:expandtab
