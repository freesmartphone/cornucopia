/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

namespace Kernel26
{

    internal const string KERNEL26_POWERSUPPLY_PLUGIN_NAME = "fsodevice.kernel26_powersupply";

/**
 * Implementation of org.freesmartphone.Device.PowerSupply for the Kernel26 Power-Class Device
 **/
class PowerSupply : FreeSmartphone.Device.PowerSupply,
                    FreeSmartphone.Info,
                    FsoFramework.AbstractObject
{
    FsoFramework.Subsystem subsystem;

    private string sysfsnode;
    private static uint counter;

    // internal (accessible for aggregate power supply)
    internal string name;
    internal string typ;
    internal FreeSmartphone.Device.PowerStatus status = FreeSmartphone.Device.PowerStatus.UNKNOWN;
    internal bool present;

    public PowerSupply( FsoFramework.Subsystem subsystem, string sysfsnode )
    {
        this.subsystem = subsystem;
        this.sysfsnode = sysfsnode;
        this.name = Path.get_basename( sysfsnode );

        if ( !FsoFramework.FileHandling.isPresent( "%s/type".printf( sysfsnode ) ) )
        {
            logger.error( "^^^ sysfs class is damaged; skipping." );
            return;
        }

        this.typ = FsoFramework.FileHandling.read( "%s/type".printf( sysfsnode ) ).down();

        Idle.add( onIdle );

        subsystem.registerObjectForService<FreeSmartphone.Device.PowerSupply>( FsoFramework.Device.ServiceDBusName, "%s/%u".printf( FsoFramework.Device.PowerSupplyServicePath, counter ), this );
        subsystem.registerObjectForService<FreeSmartphone.Info>( FsoFramework.Device.ServiceDBusName, "%s/%u".printf( FsoFramework.Device.PowerSupplyServicePath, counter++ ), this );

        logger.info( "Created" );
    }

    public override string repr()
    {
        return @"<$sysfsnode>";
    }

    public bool onIdle()
    {
        // trigger initial coldplug change notification, if we are on a real sysfs
        if ( sysfsnode.has_prefix( "/sys" ) )
        {
            assert( logger.debug( "Triggering initial coldplug change notification" ) );
            FsoFramework.FileHandling.write( "change", "%s/uevent".printf( sysfsnode ) );
        }
        else
        {
            assert( logger.debug( "Synthesizing initial coldplug change notification" ) );
            var uevent = FsoFramework.FileHandling.read( "%s/uevent".printf( sysfsnode ) );
            var parts = uevent.split( "\n" );
            var properties = new HashTable<string, string>( str_hash, str_equal );
            foreach ( var part in parts )
            {
#if DEBUG
                message( "%s", part );
#endif
                var elements = part.split( "=" );
                if ( elements.length == 2 )
                {
                    properties.insert( elements[0], elements[1] );
                }
            }
            aggregate.onPowerSupplyChangeNotification( properties );
        }
        return false; // mainloop: don't call again
    }

    public bool isBattery()
    {
        return typ == "battery";
    }

    public bool isPresent()
    {
        var node = isBattery() ? "%s/present" : "%s/online";
        var value = FsoFramework.FileHandling.read( node.printf( sysfsnode ) );
        return ( value != null && value == "1" );
    }

    public int getCapacity()
    {
        if ( !isBattery() )
            return -1;
        if ( !isPresent() )
            return -1;

        // try the capacity node first, this one is not supported by all power class devices
        var value = FsoFramework.FileHandling.readIfPresent( "%s/capacity".printf( sysfsnode ) );
        if ( value != "" )
            return value.to_int();

#if DEBUG
        message( "capacity node not available, using energy_full and energy_now" );
#endif

        // then, try energy_full and energy_now
        var energy_full = FsoFramework.FileHandling.readIfPresent( "%s/energy_full".printf( sysfsnode ) );
        var energy_now = FsoFramework.FileHandling.readIfPresent( "%s/energy_now".printf( sysfsnode ) );
        if ( energy_full != "" && energy_now != "" )
            return (int) ( ( energy_now.to_double()  / energy_full.to_double() ) * 100.0 );

        // as a last resort, try charge_full and charge_now
        var charge_full = FsoFramework.FileHandling.readIfPresent( "%s/charge_full".printf( sysfsnode ) );
        var charge_now = FsoFramework.FileHandling.readIfPresent( "%s/charge_now".printf( sysfsnode ) );
        if ( charge_full != "" && charge_now != "" )
            return (int) ( ( charge_now.to_double()  / charge_full.to_double() ) * 100.0 );

        return -1;
    }

    //
    // FreeSmartphone.Info (DBUS API)
    //
    public async HashTable<string,Variant> get_info() throws DBusError, IOError
    {
        var res = new HashTable<string,Variant>( str_hash, str_equal );
        res.insert( "name", name );

        var dir = Dir.open( sysfsnode );
        var entry = dir.read_name();
        while ( entry != null )
        {
            if ( entry != "uevent" )
            {
                var filename = Path.build_filename( sysfsnode, entry );
                var contents = FsoFramework.FileHandling.read( filename );
                if ( contents != "" )
                {
                    res.insert( entry, contents );
                }
            }
            entry = dir.read_name();
        }
        return res;
    }

    //
    // FreeSmartphone.Device.PowerStatus (DBUS API)
    //
    public async FreeSmartphone.Device.PowerStatus get_power_status() throws DBusError, IOError
    {
        return status;
    }

    public async int get_capacity() throws DBusError, IOError
    {
        return getCapacity();
    }
}

/**
 * Implementation of org.freesmartphone.Device.PowerSupply as aggregated Kernel26 Power-Class Devices
 **/
class AggregatePowerSupply : FreeSmartphone.Device.PowerSupply, FsoFramework.AbstractObject
{
    private const uint POWER_SUPPLY_CAPACITY_CHECK_INTERVAL = 5 * 60;
    private const uint POWER_SUPPLY_CAPACITY_CRITICAL = 7;
    private const uint POWER_SUPPLY_CAPACITY_EMPTY = 3;

    private FsoFramework.Subsystem subsystem;
    private string sysfsnode;

    private FreeSmartphone.Device.PowerStatus status = FreeSmartphone.Device.PowerStatus.UNKNOWN;
    private int energy = -1;
    private string[] supported_chargers = { "usb", "mains" }; // FIXME make this a config option

    public AggregatePowerSupply( FsoFramework.Subsystem subsystem, string sysfsnode )
    {
        this.subsystem = subsystem;
        this.sysfsnode = sysfsnode;

        subsystem.registerObjectForService<FreeSmartphone.Device.PowerSupply>( FsoFramework.Device.ServiceDBusName, FsoFramework.Device.PowerSupplyServicePath, this );

        FsoFramework.BaseKObjectNotifier.addMatch( "change", "power_supply", onPowerSupplyChangeNotification );

        if ( instances.length() > 0 )
        {
            Idle.add( onIdle );
        }

        logger.info( "Created" );
    }

    public override string repr()
    {
        return @"<$sysfsnode>";
    }

    public bool onIdle()
    {
        onTimeout();
        Timeout.add_seconds( POWER_SUPPLY_CAPACITY_CHECK_INTERVAL, onTimeout );
        return false;
    }

    public bool onTimeout()
    {
        var capacity = getCapacity();
        sendCapacityIfChanged( capacity );
        if ( status == FreeSmartphone.Device.PowerStatus.DISCHARGING )
        {
            if ( capacity <= POWER_SUPPLY_CAPACITY_EMPTY )
            {
                sendStatusIfChanged( FreeSmartphone.Device.PowerStatus.EMPTY );
            }
            else if ( capacity <= POWER_SUPPLY_CAPACITY_CRITICAL )
            {
                sendStatusIfChanged( FreeSmartphone.Device.PowerStatus.CRITICAL );
            }
        }
        return true;
    }

    public void onPowerSupplyChangeNotification( HashTable<string,string> properties )
    {
        var name = properties.lookup( "POWER_SUPPLY_NAME" );
        if ( name == null )
        {
            logger.warning( "POWER_SUPPLY_NAME not present, ignoring power supply change notification" );
            return;
        }
        var technology = properties.lookup( "POWER_SUPPLY_TECHNOLOGY" );
        var typ = properties.lookup( "POWER_SUPPLY_TYPE" );
        if ( typ == null )
        {
            logger.warning( "POWER_SUPPLY_TYPE not present, checking for POWER_SUPPLY_TECHNOLOGY..." );
            if ( technology != null )
            {
                logger.warning( "Present; treating it like a battery" );
                typ = "battery";
            }
            else
            {
                logger.warning( "Not present; treating it like an AC adapter" );
                typ = "ac";
            }
        }

        var status = "unknown";
        var present = false;

        if ( typ.down() != "battery" )
        {
            var online = properties.lookup( "POWER_SUPPLY_ONLINE" );
            if ( online == null )
            {
                logger.warning( "POWER_SUPPLY_ONLY not present, ignoring power supply change notification" );
                return;
            }
            present = ( online.down() == "1" );
            status = present ? "online" : "offline";
        }
        else
        {
            var pres = properties.lookup( "POWER_SUPPLY_PRESENT" );
            if ( pres == null )
            {
                logger.warning( "POWER_SUPPLY_PRESENT not present, ignoring power supply change notification" );
                return;
            }
            var stat = properties.lookup( "POWER_SUPPLY_STATUS" );
            if ( stat == null )
            {
                logger.warning( "POWER_SUPPLY_STATUS not present, battery might have been removed"  );
                stat = "unknown";
            }
            present = ( pres.down() == "1" );
            status = stat.down();

            if ( !present )
            {
                status = "removed";
            }
            else
            {
                if ( status == "not charging" )
                {
                    status = "full";
                }
            }
        }

        assert( status != null );

        logger.info( @"Got power status change notification for $name: $status" );

        // set status in instance
        foreach ( var supply in instances )
        {
            if ( supply.name == name )
            {
                supply.present = present;
                switch ( status )
                {
                    case "unknown":
                        supply.status = FreeSmartphone.Device.PowerStatus.UNKNOWN;
                        break;
                    case "error":
                        supply.status = FreeSmartphone.Device.PowerStatus.UNKNOWN; // unknown as well
                        break;
                    case "online":
                        supply.status = FreeSmartphone.Device.PowerStatus.ONLINE;
                        break;
                    case "offline":
                        supply.status = FreeSmartphone.Device.PowerStatus.OFFLINE;
                        break;
                    case "removed":
                        supply.status = FreeSmartphone.Device.PowerStatus.REMOVED;
                        break;
                    case "charging":
                        supply.status = FreeSmartphone.Device.PowerStatus.CHARGING;
                        break;
                    case "discharging":
                        supply.status = FreeSmartphone.Device.PowerStatus.DISCHARGING;
                        break;
                    case "full":
                        supply.status = FreeSmartphone.Device.PowerStatus.FULL;
                        break;
                    default:
                        logger.error( "Received unexpected power status" );
                        break;
                }
            }
        }

        computeNewStatus();
    }

    public void computeNewStatus()
    {
        var statusForAll = true;
        PowerSupply battery = null;
        PowerSupply[] chargers = { };

        // first, check whether we have enough information to compute the status at all
        foreach ( var supply in instances )
        {
            assert( logger.debug( @"supply $(supply.name) status = $(supply.status)" ) );
            assert( logger.debug( @"supply $(supply.name) type = $(supply.typ)" ) );

            if ( supply.status == FreeSmartphone.Device.PowerStatus.UNKNOWN )
            {
                statusForAll = false;
                break;
            }

            if ( supply.typ == "battery" ) // FIXME: revisit to handle multiple batteries
            {
                battery = supply;
            }
            else
            {
                if ( supply.status == FreeSmartphone.Device.PowerStatus.ONLINE )
                {
                    if ( supply.typ in supported_chargers )
                        chargers += supply;
                }
            }
        }

        if ( !statusForAll )
        {
            assert( logger.debug( "^^^ not enough information present to compute overall status" ) );
            return;
        }

        // if we have charger inserted and present, AC is our status
        if ( chargers.length > 0 )
        {
            foreach ( var charger in chargers )
            {
                if ( charger.status == FreeSmartphone.Device.PowerStatus.ONLINE )
                {
                    sendStatusIfChanged( FreeSmartphone.Device.PowerStatus.AC );
                    return;
                }
            }
        }

        // if we have a battery and it is inserted, this is our aggregate status
        if ( battery != null && battery.status != FreeSmartphone.Device.PowerStatus.REMOVED )
        {
            sendStatusIfChanged( battery.status );
        }
        // if we don't have a battery, we're on AC
        // FIXME: in that case we should give the name of the charger that charges us via get_info
        else
        {
            sendStatusIfChanged( FreeSmartphone.Device.PowerStatus.AC );
        }
    }

    public void sendStatusIfChanged( FreeSmartphone.Device.PowerStatus status )
    {
        logger.debug( "sendStatusIfChanged old %d new %d".printf( this.status, status ) );

        // some power supply classes (Thinkpad) have a bug where after
        // 'discharging' you shortly get a 'full' before 'charging'
        // when you insert the AC plug.
        if ( ( this.status == FreeSmartphone.Device.PowerStatus.DISCHARGING ) && ( status == FreeSmartphone.Device.PowerStatus.FULL ) )
        {
            logger.warning( "BUG: power supply class sent 'full' after 'discharging'" );
            return;
        }

        if ( this.status == status )
            return;

        this.status = status;
        power_status( status ); // DBUS SIGNAL
    }

    public void sendCapacityIfChanged( int energy )
    {
        if ( this.energy == energy )
        return;

        this.energy = energy;
        capacity( energy ); // DBUS SIGNAL
    }

    public int getCapacity()
    {
        var amount = 0;
        var numValues = 0;
        // walk through all power nodes and compute arithmetic mean
        foreach( var supply in instances )
        {
            var v = supply.getCapacity();
            if ( v != -1 )
            {
                amount += v;
                numValues++;
            }
        }
        return numValues > 0 ? amount / numValues : -1;
    }

    //
    // FreeSmartphone.Device.PowerSupply (DBUS API)
    //
    public async string get_name() throws DBusError, IOError
    {
        return Path.get_basename( sysfsnode );
    }

    public async HashTable<string,Variant> get_info() throws DBusError, IOError
    {
        var res = new HashTable<string,Variant>( str_hash, str_equal );
        //FIXME: add more infos
        res.insert( "type", "aggregate" );
        return res;
    }

    public async FreeSmartphone.Device.PowerStatus get_power_status() throws DBusError, IOError
    {
        return status;
    }

    public async int get_capacity() throws DBusError, IOError
    {
        return getCapacity();
    }
}

} /* namespace */

internal static string sysfs_root;
internal static string sys_class_powersupplies;
internal List<Kernel26.PowerSupply> instances;
internal Kernel26.AggregatePowerSupply aggregate;

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    // grab sysfs paths
    var config = FsoFramework.theConfig;
    sysfs_root = config.stringValue( "cornucopia", "sysfs_root", "/sys" );
    sys_class_powersupplies = "%s/class/power_supply".printf( sysfs_root );

    // scan sysfs path for power supplies
    var dir = Dir.open( sys_class_powersupplies );
    var entry = dir.read_name();
    var ignoreList = config.stringListValue( Kernel26.KERNEL26_POWERSUPPLY_PLUGIN_NAME, "ignore", new string[] {} );

    while ( entry != null )
    {
        if ( !(entry in ignoreList) )
        {
            var filename = Path.build_filename( sys_class_powersupplies, entry );
            instances.append( new Kernel26.PowerSupply( subsystem, filename ) );
        }
        entry = dir.read_name();
    }

    // always create aggregated object
    aggregate = new Kernel26.AggregatePowerSupply( subsystem, sys_class_powersupplies );

    return Kernel26.KERNEL26_POWERSUPPLY_PLUGIN_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsodevice.kernel26_powersupply fso_register_function()" );
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
