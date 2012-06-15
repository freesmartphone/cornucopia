/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

namespace DBusService
{
    const string MODULE_NAME = "fsogsm.dbus_service";
    public ModemManager modem_manager;
}

public class ModemManager : FsoFramework.AbstractDBusResource, FsoGsm.IModemManager
{
    private Gee.ArrayList<FsoGsm.DeviceServiceManager> _modemServices;
    private FsoFramework.Subsystem _subsystem;
    private int next_id = 0;
    private ServiceState state = ServiceState.DISABLED;

    //
    // private
    //

    private void setup_primary_modem()
    {
        var modemtype = FsoFramework.theConfig.stringValue( "fsogsm", "modem_type", "none" );

        if ( modemtype == "none" || modemtype == "" )
        {
            logger.info( @"No primary modem configured; starting without an activated modem" );
            return;
        }

        if ( !FsoGsm.ModemFactory.validateModemType( modemtype ) )
        {
            logger.error( @"Can't find modem for modem_type $modemtype; corresponding modem plugin loaded?" );
            return;
        }

        var modem = FsoGsm.ModemFactory.createFromTypeName( modemtype );
        register_modem( modem );
    }

    //
    // public API
    //

    public ModemManager( FsoFramework.Subsystem subsystem )
    {
        base( "GSM", subsystem );

        _subsystem = subsystem;
        _modemServices = new Gee.ArrayList<FsoGsm.DeviceServiceManager>();

        FsoGsm.theModemManager = this;
        setup_primary_modem();
    }

    public async void shutdown()
    {
        foreach ( var service in _modemServices )
        {
            if ( service.modem.status() > FsoGsm.Modem.Status.CLOSED && service.modem.status() < FsoGsm.Modem.Status.CLOSING )
                yield service.disable();
        }
    }

    public async void register_modem( FsoGsm.Modem modem )
    {
        var service_manager = new FsoGsm.DeviceServiceManager( next_id, modem, _subsystem );
        _modemServices.add( service_manager );

        if ( state == ServiceState.ENABLED )
            yield service_manager.enable();

        next_id++;
    }

    public async void unregister_modem( FsoGsm.Modem modem )
    {
        FsoGsm.DeviceServiceManager? modemServiceToRemove = null;

        foreach ( var service in _modemServices )
        {
            if ( service.modem == modem )
            {
                modemServiceToRemove = service;
                break;
            }
        }

        if ( modemServiceToRemove != null )
        {
            if ( modemServiceToRemove.state == ServiceState.ENABLED )
                yield modemServiceToRemove.disable();

            modemServiceToRemove.unregister_services();
            _modemServices.remove( modemServiceToRemove );
        }
    }

    public override async void enableResource() throws FreeSmartphone.ResourceError
    {
        assert( logger.debug( "Enabling GSM resource..." ) );

        state = ServiceState.ENABLED;

        foreach ( var service in _modemServices )
        {
            var result = yield service.enable();
            // FIXME should this fail when one modem can't be enabled?
            // throw new FreeSmartphone.ResourceError.UNABLE_TO_ENABLE( "Can't open the modem." );
        }
    }

    public override async void disableResource()
    {
        assert( logger.debug( "Disabling GSM resource..." ) );

        state = ServiceState.DISABLED;

        foreach ( var service in _modemServices )
        {
            yield service.disable();
        }
    }

    public override async void suspendResource()
    {
        assert( logger.debug( "Suspending GSM resource..." ) );

        state = ServiceState.SUSPENDED;

        foreach ( var service in _modemServices )
        {
            yield service.suspend();
        }

    }

    public override async void resumeResource()
    {
        assert( logger.debug( "Resuming GSM resource..." ) );

        state = ServiceState.ENABLED;

        foreach ( var service in _modemServices )
        {
            yield service.resume();
        }
    }

    public override async GLib.HashTable<string,GLib.Variant?> dependencies()
    {
        var dependencies = new GLib.HashTable<string,GLib.Variant?>( GLib.str_hash, GLib.str_equal );

        // Service dependencies can be defined dynamically by the plugins with accessing
        // the theServiceDependencies global variable.
        string services = "";
        bool first = true;
        foreach ( var service in FsoGsm.theServiceDependencies )
        {
            if ( !first )
                services += ",";
            services += service;
            first = false;
        }

        dependencies.insert( "services", services );

        return dependencies;
    }

    public override string repr()
    {
        return @"<>";
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
    DBusService.modem_manager = new ModemManager( subsystem );
    return DBusService.MODULE_NAME;
}

/**
 * This function gets called on subsystem shutdown time.
 **/
public static void fso_shutdown_function() throws Error
{
#if DEBUG
    debug( "SHUTDOWN ENTER" );
#endif
    running = true;
    async_helper();
    while ( running )
    {
        GLib.MainContext.default().iteration( true );
    }
#if DEBUG
    debug( "SHUTDOWN LEAVE" );
#endif
}

static bool running;
internal async void async_helper()
{
#if DEBUG
    debug( "ASYNC_HELPER ENTER" );
#endif
    // yield resource.disableResource();
    yield FsoGsm.theModemManager.shutdown();
    running = false;
#if DEBUG
    debug( "ASYNC_HELPER_DONE" );
#endif
}

/**
 * Module init function, DON'T REMOVE THIS!
 **/
[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsogsm.dbus_service fso_register_function" );
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
