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

class Led : FreeSmartphone.Device.LED, FsoFramework.AbstractObject
{
    public const string MODULE_NAME = "fsodevice.kernel26_leds";

    FsoFramework.Subsystem subsystem;

    private int max_brightness;
    private string sysfsnode;
    private string brightness;
    private string trigger;
    private string triggers;

    private uint blinktimeoutwatch;

    static uint counter;

    public Led( FsoFramework.Subsystem subsystem, string sysfsnode )
    {
        this.subsystem = subsystem;
        this.sysfsnode = sysfsnode;
        this.max_brightness = FsoFramework.FileHandling.read( this.sysfsnode + "/max_brightness" ).to_int();
        if ( max_brightness == 0 )
        {
            max_brightness = FsoFramework.theConfig.intValue(MODULE_NAME, "max_brightness", 255);
        }

        this.brightness = sysfsnode + "/brightness";
        this.trigger = sysfsnode + "/trigger";

        if ( !FsoFramework.FileHandling.isPresent( this.brightness ) ||
             !FsoFramework.FileHandling.isPresent( this.trigger ) )
        {
            logger.error( "^^^ sysfs class is damaged; skipping." );
            return;
        }

        subsystem.registerObjectForService<FreeSmartphone.Device.LED>( FsoFramework.Device.ServiceDBusName, "%s/%s".printf( FsoFramework.Device.LedServicePath, Path.get_basename( sysfsnode ) ), this );
        // FIXME: remove in release code, can be done lazily
        initTriggers();

        logger.info( "Created" );
    }

    public override string repr()
    {
        return @"<$sysfsnode>";
    }

    public void initTriggers()
    {
        if ( triggers == null )
        {
            triggers = FsoFramework.FileHandling.read( trigger );
            logger.info( "^^^ supports the following triggers: '%s'".printf( triggers ) );
        }
    }

    public void cleanTimeout()
    {
        if ( blinktimeoutwatch > 0 )
            Source.remove( blinktimeoutwatch );
    }

    public void setTimeout( int seconds )
    {
        cleanTimeout();
        blinktimeoutwatch = Timeout.add_seconds( seconds, onTimeout );
    }

    public bool onTimeout()
    {
        set_brightness( 0 );
        return false;
    }

    private int _valueToPercent( int value )
    {
        double max = max_brightness;
        double v = value;
        return (int)(100.0 / max * v);
    }

    private int _percentToValue( int percent )
    {
        double p = percent;
        double max = max_brightness;
        double value;
        if ( percent >= 100 )
            value = max_brightness;
        else if ( percent <= 0 )
            value = 0;
        else
            value = p / 100.0 * max;
        return (int)value;
    }

    //
    // FreeSmartphone.Device.LED (DBUS API)
    //
    public async string get_name() throws DBusError, IOError
    {
        return Path.get_basename( sysfsnode );
    }

    public async void set_brightness( int brightness ) throws DBusError, IOError
    {
        var percent = _percentToValue( brightness );

        cleanTimeout();

        FsoFramework.FileHandling.write( "none", this.trigger );
        FsoFramework.FileHandling.write( percent.to_string(), this.brightness );
    }

    public async void set_blinking( int delay_on, int delay_off ) throws FreeSmartphone.Error, DBusError, IOError
    {
        initTriggers();

        if ( !( "timer" in triggers ) )
            throw new FreeSmartphone.Error.UNSUPPORTED( "Kernel support for timer led class trigger missing." );

        cleanTimeout();

        FsoFramework.FileHandling.write( "timer", this.trigger );
        FsoFramework.FileHandling.write( delay_on.to_string(), this.sysfsnode + "/delay_on" );
        FsoFramework.FileHandling.write( delay_off.to_string(), this.sysfsnode + "/delay_off" );
    }

    public async void blink_seconds( int seconds, int delay_on, int delay_off ) throws FreeSmartphone.Error, DBusError, IOError
    {
        if ( seconds < 1 )
            throw new FreeSmartphone.Error.INVALID_PARAMETER( "Blinking timeout needs to be at least 1 second." );

        yield set_blinking( delay_on, delay_off );

        setTimeout( seconds );
    }

    public async void set_networking( string iface, string mode ) throws FreeSmartphone.Error, DBusError, IOError
    {
        initTriggers();

        if ( !( "netdev" in triggers ) )
            throw new FreeSmartphone.Error.UNSUPPORTED( "Kernel support for netdev led class trigger missing." );

        if ( !FsoFramework.FileHandling.isPresent( "%s/%s".printf( sys_class_net, iface ) ) )
            throw new FreeSmartphone.Error.INVALID_PARAMETER( "Interface '%s' not present.".printf( iface ) );

        string cleanmode = "";

        foreach ( var element in mode.split( " " ) )
        {
            if ( element != "link" && element != "rx" && element != "tx" )
                throw new FreeSmartphone.Error.INVALID_PARAMETER( "Element '%s' not allowed. Valid elements are 'link', 'rx', 'tx'.".printf( element ) );
            else
                cleanmode += element;
        }
        if ( cleanmode == "" )
        {
            set_brightness( 0 );
        }
        else
        {
            cleanTimeout();

            FsoFramework.FileHandling.write( "netdev", this.trigger );
            FsoFramework.FileHandling.write( iface, this.sysfsnode + "/device_name" );
            FsoFramework.FileHandling.write( cleanmode, this.sysfsnode + "/mode" );
        }
    }
}

} /* namespace */

static string sysfs_root;
static string sys_class_net;
static string sys_class_leds;
List<Kernel26.Led> instances;

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
    sys_class_leds = "%s/class/leds".printf( sysfs_root );
    sys_class_net = "%s/class/net".printf( sysfs_root );

    var to_skip = config.stringValue( Kernel26.Led.MODULE_NAME, "ignore_by_name", "" );

    // scan sysfs path for leds
    var dir = Dir.open( sys_class_leds );
    var entry = dir.read_name();
    while ( entry != null )
    {
        if ( ( to_skip != "" ) && ( to_skip in entry ) )
        {
            entry = dir.read_name();
            continue;
        }
        var filename = Path.build_filename( sys_class_leds, entry );
        instances.append( new Kernel26.Led( subsystem, filename ) );
        entry = dir.read_name();
    }
    return Kernel26.Led.MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsodevice.kernel26_leds fso_register_function()" );
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
