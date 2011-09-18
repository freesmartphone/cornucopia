/*
 * Copyright (C) 2011 Klaus 'mrmoku' Kurzmann <mok@fluxnetz.de>
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

namespace FsoAudio
{
    public static const string ROUTER_ACI_MODULE_NAME = "fsoaudio.router_aci";
}


public class Router.Aci : FsoAudio.AbstractRouter
{
    private FsoAudio.SoundDevice device;
    private Gee.HashMap<string,FsoAudio.AciRoute> aci;
    private Gee.HashMap<FreeSmartphone.Audio.Device,FsoAudio.AciDevice> normalAciDevices;
    private Gee.HashMap<FreeSmartphone.Audio.Device,FsoAudio.AciDevice> callAciDevices;
    private GLib.Queue<FsoAudio.AciDevice> usedstack;
    private string configurationPath;
    private string dataPath;


    construct
    {
        initAci();
        logger.info( @"Created and configured.");
    }

    private void addAci( File file )
    {
        int priority = 1;
        var name = file.get_basename();
        FsoAudio.AciControl[] controls = {};
        FsoAudio.AciControl mastervol = null;

        try
        {
            // Open file for reading and wrap returned FileInputStream into a
            // DataInputStream, so we can read line by line
            var in_stream = new DataInputStream( file.read( null ) );
            string line;
            // Read lines until end of file (null) is reached
            while ( ( line = in_stream.read_line( null, null ) ) != null )
            {
                var stripped = line.strip();
                if ( stripped == "")  // skip empty lines
                    continue;
                if ( stripped.has_prefix( "#" ) ) // check for @prio= in global comments
                {
                    var pos = stripped.index_of( "@prio=" );
                    if ( pos > 0 )
                        priority = stripped.offset( pos + 6 ).to_int();
                    continue;
                }
                var control = device.controlForAmixString( line );
                controls += control;
                if ( stripped.contains( "@mastervol" ) )
                    mastervol = control;
            }
#if DEBUG
            debug( "ACI Route %s successfully read from file %s".printf( name, file.get_path() ) );
#endif
            var route = new FsoAudio.AciRoute( controls, priority, mastervol );
            aci[name] = route;
        }
        catch ( IOError e )
        {
            FsoFramework.theLogger.warning( "%s".printf( e.message ) );
        }
    }

    private Gee.HashMap<FreeSmartphone.Audio.Device,string> readDeviceAci( FsoFramework.SmartKeyFile alsaconf, GLib.List<string> sections )
    {
        var result = new Gee.HashMap<string,FreeSmartphone.Audio.Device>();

        foreach ( var section in sections )
        {
            var device_name = section.split( "." )[1];
            if ( device_name != "" )
            {
                var speaker_route = alsaconf.stringValue( section, "speaker_route", "" );
                if ( speaker_route != "" && !aci.has_key( speaker_route ) )
                {
                    FsoFramework.theLogger.warning( @"Speaker route $speaker_route for device $device_name does not exist. Ignoring." );
                    continue;
                }

                var mic_route = alsaconf.stringValue( section, "mic_route", "" );
                if ( mic_route != "" && !aci.has_key( mic_route ) )
                {
                    FsoFramework.theLogger.warning( @"Mic route $mic_route for device $device_name does not exist. Ignoring." );
                    continue;
                }

                var device_type = FsoFramework.StringHandling.enumFromNick<FreeSmartphone.Audio.Device>( device_name );
                result.set( device_type, new FsoAudio.AciDevice( aci[speaker_route], aci[mic_route] ) );
            }
        }

        return result;
    }

    private FreeSmartphone.Audio.Device[] buildDeviceList( Gee.HashMap<FreeSmartphone.Audio.Device,FsoAudio.AciDevice> deviceMap )
    {
        FreeSmartphone.Audio.Device[] devices = new FreeSmartphone.Audio.Device[] { };

        foreach ( var device in deviceMap.keys )
        {
            devices += device;
        }

        return devices;
    }

    private void initAci()
    {
        GLib.List<string> sections;
        aci = new Gee.HashMap<string,FsoAudio.AciRoute>();
        usedstack = new GLib.List<FsoAudio.AciRoute>();
        configurationPath = FsoFramework.Utility.machineConfigurationDir() + "/alsa.conf";
        FsoFramework.SmartKeyFile alsaconf = new FsoFramework.SmartKeyFile();
        if ( alsaconf.loadFromFile( configurationPath ) )
        {
            var soundcard = alsaconf.stringValue( "alsa", "cardname", "default" );
            dataPath = FsoFramework.Utility.machineConfigurationDir() + @"/aci";

            try
            {
                device = FsoAudio.SoundDevice.create( soundcard );
            }
            catch ( FsoAudio.SoundError e )
            {
                FsoFramework.theLogger.warning( @"Sound card problem: $(e.message)" );
                return;
            }

            /* first load all existing aci routes */
            var acifiles = FsoFramework.FileHandling.listDirectory( dataPath );
            foreach ( var f in acifiles )
            {
                addAci( File.new_for_path( f ) );
            }

            /* then build the configured devices - each device can
             * consist of a speaker and a mic route */

            sections = alsaconf.sectionsWithPrefix( "normal." );
            normalAciDevices = readDeviceAci( alsaconf, sections );
            normal_supported_devices = buildDeviceList( normalAciDevices );

            sections = alsaconf.sectionsWithPrefix( "call." );
            callAciDevices = readDeviceAci( alsaconf, sections );
            call_supported_devices = buildDeviceList( callAciDevices );
        }
    }

    private bool canSetDevice( FreeSmartphone.Audio.Mode mode, FreeSmartphone.Audio.Device device )
    {
        var map = mode == FreeSmartphone.Audio.Mode.NORMAL ?  normalAciDevices : callAciDevices;
        if ( !map.has_key( device ) )
            return false;


    }

    private void applyRoutesForDevice( FreeSmartphone.Audio.Device device )
    {
        var map = current_mode == FreeSmartphone.Audio.Mode.NORMAL ?  normalAciDevices : callAciDevices;
        if ( !map.has_key( device ) )
            return;
        var acidev = map[ device ];
        assert( device != null );
        device.setAciRoute( acidev.speaker_route );
        device.setAciRoute( acidev.mic_route );
    }

    public override string repr()
    {
        return "<>";
    }

    public override void set_mode( FreeSmartphone.Audio.Mode mode, bool force = false )
    {
        if ( !force && mode == current_mode )
        {
            return;
        }

        if ( !canSetDevice( mode, current_device ) )
        {
            logger.warning( @"Cannot switch to new mode $mode; keeping old mode $current_mode" );
            return;
        }

        base.set_mode( mode );
        applyRoutesForDevice( current_device );
    }

    public override void set_device( FreeSmartphone.Audio.Device device, bool expose = true )
    {
        if ( device == current_device )
        {
            return;
        }

        base.set_device( device, expose );

        if ( !expose )
        {
            return;
        }

        applyRoutesForDevice( device );
    }

    public override void set_volume( FreeSmartphone.Audio.Control control, uint volume )
    {
        var device = usedstack.peek_head();
        assert( device != null );

        var ctl = control == FreeSmartphone.Audio.Control.SPEAKER ? device.speaker_route.mastervol : device.mic_route.mastervol;
        device.setVolumeForIndex( ctl.eid, (uint8) volume );
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
    return FsoAudio.ROUTER_ACI_MODULE_NAME;
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    FsoFramework.theLogger.debug( "fsoaudio.router_aci fso_register_function" );
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
