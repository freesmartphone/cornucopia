/*
 * Copyright (C) 2012 Simon Busch
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

namespace Bluez
{
    [DBus (name = "org.bluez")]
    public errordomain Error
    {
        [DBus (name = "InvalidArguments")]
        INVALID_ARGUMENTS,
        [DBus (name = "Failed")]
        FAILED,
    }

    [DBus (name = "org.bluez.Manager", timeout = 120000)]
    public interface IManager : GLib.Object
    {
        [DBus (name = "GetProperties")]
        public abstract async GLib.HashTable<string, GLib.Variant> get_properties() throws DBusError, IOError;

        [DBus (name = "DefaultAdapter")]
        public abstract async GLib.ObjectPath default_adapter() throws DBusError, IOError;

        [DBus (name = "PropertyChanged")]
        public signal void property_changed(string param0, GLib.Variant param1);
        [DBus (name = "AdapterAdded")]
        public signal void adapter_added(GLib.ObjectPath param0);
        [DBus (name = "AdapterRemoved")]
        public signal void adapter_removed(GLib.ObjectPath param0);
    }

    [DBus (name = "org.bluez.Adapter", timeout = 120000)]
    public interface IAdapter : GLib.Object
    {
        [DBus (name = "GetProperties")]
        public abstract async GLib.HashTable<string, GLib.Variant> get_properties() throws DBusError, IOError;

        [DBus (name = "ListDevices")]
        public abstract async GLib.ObjectPath[] list_devices() throws DBusError, IOError;

        [DBus (name = "DeviceCreated")]
        public signal void device_created(GLib.ObjectPath param0);

        [DBus (name = "DeviceRemoved")]
        public signal void device_removed(GLib.ObjectPath param0);
    }

    [DBus (name = "org.bluez.Device", timeout = 120000)]
    public interface IDevice : GLib.Object
    {
        [DBus (name = "GetProperties")]
        public abstract async GLib.HashTable<string, GLib.Variant> get_properties() throws DBusError, IOError;

        [DBus (name = "PropertyChanged")]
        public signal void property_changed( string name, GLib.Variant value );
    }

    [DBus (name = "org.bluez.HandsfreeGateway")]
    public interface IHandsfreeGateway : GLib.Object
    {
        [DBus (name = "Connect")]
        public abstract async void connect() throws DBusError, IOError;
        [DBus (name = "Disconnect")]
        public abstract async void disconnect() throws DBusError, IOError;
        [DBus (name = "GetProperties")]
        public abstract async GLib.HashTable<string,Variant> get_properties() throws DBusError, IOError;
        [DBus (name = "RegisterAgent")]
        public abstract async void register_agent( GLib.ObjectPath path ) throws DBusError, IOError;
        [DBus (name = "UnregisterAgent")]
        public abstract async void unregister_agent( GLib.ObjectPath path ) throws Bluez.Error, DBusError, IOError;

        [DBus (name = "PropertyChanged")]
        public signal void property_changed( string name, Variant value );
    }

    [DBus (name = "org.bluez.HandsfreeAgent")]
    public interface IHandsfreeAgent : GLib.Object
    {
        [DBus (name = "NewConnection")]
        public abstract async void new_connection( GLib.Socket fd, uint16 version ) throws Bluez.Error, DBusError, IOError;
        [DBus (name = "Release")]
        public abstract async void release() throws DBusError, IOError;
    }
}

public interface FsoGsm.IBluetoothProfile : GLib.Object
{
    /**
     * @param device_path
     **/
    public abstract async bool probe( string device_path );

    /**
     * @param path
     **/
    public abstract async void remove( string path );
}

public class FsoGsm.BluetoothManager : FsoFramework.AbstractObject
{
    private class ProfileHandler
    {
        public string id;
        public IBluetoothProfile client;
        public Gee.ArrayList<string> devices;

        public ProfileHandler( string id, IBluetoothProfile client )
        {
            this.id = id;
            this.client = client;
            this.devices = new Gee.ArrayList<string>();
        }
    }

    private Bluez.IManager _manager;
    private List<ProfileHandler> _profiles;
    private GLib.HashTable<string,Bluez.IAdapter> _adapters;
    private bool _initialized = false;
    private DBusConnection _connection;
    private int _ref_count = 0;
    private uint _service_watch = 0;
    private uint _property_changed_watch = 0;

    //
    // private
    //

    private async void activate_profile( ProfileHandler ph, string device_path )
    {
        var success = yield ph.client.probe( device_path );
        if ( success )
            ph.devices.add( (ObjectPath) device_path );
    }

    private async void check_adapter_for_device_profile( ProfileHandler ph, string adapter_path )
    {
        try
        {
            var adapter = yield Bus.get_proxy<Bluez.IAdapter>( BusType.SYSTEM, "org.bluez", adapter_path );

            var aprops = yield adapter.get_properties();
            var devices = aprops.lookup( "Devices" );
            if ( devices == null )
                return;

            for ( var m = 0; m < devices.n_children(); m++ )
            {
                var device_path = devices.get_child_value( m ).get_string();
                assert( logger.debug( @"Processing device $device_path for profile $(ph.id)  ..." ) );
                var device = yield Bus.get_proxy<Bluez.IDevice>( BusType.SYSTEM, "org.bluez", device_path );
                var dprops = yield device.get_properties();
                if ( dprops.lookup( "UUIDs" ) == null )
                    continue;

                var uuids = dprops.lookup( "UUIDs" ).dup_strv();
                if ( ph.id in uuids && !ph.devices.contains( device_path ) )
                {
                    assert( logger.debug( @"Found profile for device $device_path ..." ) );
                    activate_profile( ph, device_path );
                }
            }
        }
        catch ( GLib.Error e )
        {
            logger.error( @"Could not check adapter $adapter_path for device profiles: $(e.message)" );
        }
    }

    /**
     * Check all available devices for the specified profile. If a device is found which
     * supports the profile the profile's probe method is called.
     *
     * @param ph Profile handler a device is searched for.
     **/
    private async void check_devices_for_profile( ProfileHandler ph )
    {
        try
        {
            var mprops = yield _manager.get_properties();
            var adapters = mprops.lookup( "Adapters" );
            if ( adapters == null )
                return;

            for ( var n = 0; n < adapters.n_children(); n++ )
            {
                var adapter_path = adapters.get_child_value( n ).get_string();
                check_adapter_for_device_profile( ph, adapter_path );
            }
        }
        catch ( GLib.Error e )
        {
            logger.error( @"Could not initialize: $(e.message)" );
        }
    }

    /**
     * Check all profiles for a removed device and call their remove method.
     *
     * @param device_path DBus object path for a device which has been removed
     **/
    private async void update_profiles_for_removed_device( GLib.ObjectPath device_path )
    {
        assert( logger.debug( @"Device $device_path was removed" ) );

        foreach ( var ph in _profiles )
        {
            assert( logger.debug( @"Checking profile $(ph.id) for devices to remove ..." ) );

            var associated = false;

            foreach ( var profile_device in ph.devices )
            {
                if ( profile_device == device_path )
                {
                    associated = true;
                    break;
                }
            }

            if ( associated )
            {
                yield ph.client.remove( device_path );
                ph.devices.remove( device_path );
            }
        }
    }

    /**
     * Check all profiles for a newly available device. The device is check wether it
     * supports any of our profiles. If a profile is supported it's probe method is
     * called.
     *
     * @param device_path DBus path for the newly available device
     */
    private async void check_profiles_for_new_device( GLib.ObjectPath device_path )
    {
        assert( logger.debug( @"Checking device $device_path for profiles ..." ) );

        try
        {
            var device = yield Bus.get_proxy<Bluez.IDevice>( BusType.SYSTEM, "org.bluez", device_path );

            var dprops = yield device.get_properties();
            if ( dprops.lookup( "UUIDs" ) == null )
                return;

            var uuids = dprops.lookup( "UUIDs" ).dup_strv();
            if ( uuids.length == 0 )
                return;

            foreach ( var ph in _profiles )
            {
                if ( ph.id in uuids )
                {
                    bool associated = false;

                    foreach ( var profile_device in ph.devices )
                    {
                        if ( profile_device == device_path )
                        {
                            assert( logger.debug( @"Profile $(ph.id) is already associated with device $device_path" ) );
                            associated = true;
                            break;
                        }
                    }

                    if ( associated )
                        continue;

                    assert( logger.debug( @"Associate profile $(ph.id) with device $device_path" ) );
                    activate_profile( ph, device_path );
                }
            }
        }
        catch ( GLib.Error e )
        {
            logger.error( @"Error while enumerating devices: $(e.message)" );
        }
    }

    private async void on_adapter_removed( ObjectPath adapter_path )
    {
        assert( logger.debug( @"Adapter was removed $adapter_path" ) );

        // remove all clients for devices on this adapter. In this case only the prefix
        // path is handed over to the client as they should remove all clients below this path
        foreach ( var ph in _profiles )
            yield ph.client.remove( adapter_path );

        _adapters.remove( adapter_path );
    }

    private async void on_adapter_added( ObjectPath adapter_path )
    {
        if ( _adapters.lookup( adapter_path ) != null )
            return;

        assert( logger.debug( @"Adapter was added on $adapter_path" ) );

        var adapter = yield Bus.get_proxy<Bluez.IAdapter>( BusType.SYSTEM, "org.bluez", adapter_path );
        adapter.device_removed.connect( path => update_profiles_for_removed_device( path ) );
        _adapters.insert( adapter_path, adapter );
    }

    private void on_device_property_changed( GLib.DBusConnection connection, string sender_name,
        string object_path, string interface_name, string signal_name, GLib.Variant parameters )
    {
        if ( signal_name != "PropertyChanged" )
            return;

        if ( parameters.n_children() != 2 )
            return;

        var property_name = parameters.get_child_value( 0 ).get_string();
        if ( property_name != "UUIDs" )
            return;

        logger.debug( @"UUIDs on path $object_path has changed" );

        check_profiles_for_new_device( (ObjectPath) object_path );
    }

    /**
     * Initialize the bluetooth manager. After this it's possible to register profiles.
     **/
    private async void initialize()
    {
        if ( _initialized )
        {
            _ref_count++;
            return;
        }

        _service_watch = Bus.watch_name( BusType.SYSTEM, "org.bluez", BusNameWatcherFlags.NONE,
            ( connection, name, owner ) => { on_service_connect(); },
            ( connection, name ) => { on_service_disconnect(); } );

        _ref_count++;
    }

    private async void check_adapter_for_device_profiles( string adapter_path )
    {
        foreach ( var ph in _profiles )
            check_adapter_for_device_profile( ph, adapter_path );
    }

    private async void on_service_connect()
    {
        try
        {
            _manager = yield Bus.get_proxy<Bluez.IManager>( BusType.SYSTEM, "org.bluez", "/" );
            _manager.adapter_removed.connect( path => on_adapter_removed( path ) );
            _manager.adapter_added.connect( path => {
                on_adapter_added( path );
                check_adapter_for_device_profiles( path );
            } );

            var mprops = yield _manager.get_properties();
            var adapters = mprops.lookup( "Adapters" );
            if ( adapters == null )
                return;

            for ( var n = 0; n < adapters.n_children(); n++ )
            {
                var adapter_path = adapters.get_child_value( n ).get_string();
                on_adapter_added( (ObjectPath) adapter_path );
                check_adapter_for_device_profiles( adapter_path );
            }

            _connection = yield Bus.get( BusType.SYSTEM );
            _property_changed_watch =  _connection.signal_subscribe( "org.bluez", "org.bluez.Device", "PropertyChanged",
                null, null, DBusSignalFlags.NONE, on_device_property_changed);

            _initialized = true;
        }
        catch ( GLib.Error e )
        {
            logger.error( @"Could not initialize: $(e.message)" );
        }
    }

    private async void on_service_disconnect()
    {
        foreach ( var ph in _profiles )
        {
            foreach ( var device_path in ph.devices )
                yield ph.client.remove( device_path );
            ph.devices = new Gee.ArrayList<string>();
        }

        _adapters = new GLib.HashTable<string,Bluez.IAdapter>( null, null );
    }

    /**
     * Shutdown the bluetooth profile manager. All registered profiles will be removed.
     **/
    private async void shutdown()
    {
        if ( !_initialized )
            return;

        _ref_count--;

        if ( _ref_count > 0 )
            return;

        Bus.unwatch_name( _service_watch );
        _connection.signal_unsubscribe( _property_changed_watch );

        _manager = null;
        _connection = null;

        _profiles = new GLib.List<ProfileHandler>();
        _adapters = new GLib.HashTable<string,Bluez.IAdapter>( null, null );

        _initialized = false;
    }

    //
    // public API
    //

    public BluetoothManager()
    {
        _profiles = new GLib.List<ProfileHandler>();
        _adapters = new GLib.HashTable<string,Bluez.IAdapter>( null, null );
    }

    /**
     * Register a new bluetooth profile handler to the manager. If a device is found which
     * supports the profile the profiles probe method is called and the profile is set to
     * active afterwards. When device were removed by the bluetooth core profiles remove
     * method is called.
     *
     * Device recovery will not start immediatly.
     *
     * @param id Bluetooth profile id
     * @param profile Profile handler class
     * @return True if profile registration was successfull, False otherwise.
     **/
    public async bool register_profile( string id, IBluetoothProfile profile )
    {
        yield initialize();

        var ph = new ProfileHandler( id, profile );
        _profiles.append( ph );

        // if we're not yet initialized checking possible devices for the profile will we
        // done when the bluetooth service is available.
        if ( _initialized )
            yield check_devices_for_profile( ph );

        return true;
    }

    public async void unregister_profile( string id )
    {
        if ( !_initialized )
            return;

        foreach ( var ph in _profiles )
        {
            if ( ph.id == id )
            {
                foreach ( var device_path in ph.devices )
                    yield ph.client.remove( device_path );
            }
        }

        shutdown();
    }

    public override string repr()
    {
        return @"<>";
    }
}
