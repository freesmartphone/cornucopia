/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2014 Sebastian Krzyszkowiak <dos@dosowisko.net>
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
using Gee;
using FsoGsm;

/**
 * @class CinterionPS8.Modem
 *
 * This modem plugin supports Cinterion PS8 modem family (PHS8, PLS8, PXS8)
 *
 **/
class CinterionPS8.Modem : FsoGsm.AbstractModem
{
    private const string CHANNEL_NAME = "main"; // "Modem" (when using two channels) or "Application" (when using only one)
    private const string URC_CHANNEL_NAME = "urc"; // "Application" (optionally)

    public override string repr()
    {
        return "<>";
    }

    public override void configureData()
    {
      assert( modem_data != null );

      modem_data.simHasReadySignal = true; // ^SSIM READY (enabled by ^SSET=1) or +CIEV: simstatus,5 (enabled by ^SIND="simstatus",1)
      modem_data.simReadyTimeout = 30; // seconds
      modem_data.atCommandRejectIncoming = "^SHUP=21,%d"; // release cause "call rejected"
      modem_data.atCommandRejectIncomingWithId = true;
      modem_data.atCommandCancelOutgoing = "^SHUP=16,%d"; // release cause "normal call clearing"
      modem_data.atCommandCancelOutgoingWithId = true;
      modem_data.atCommandReleaseAllActive = "+CHUP";
      modem_data.atCommandReleaseAllHeld = "+CHUP";

      registerAtCommandSequence( "MODEM", "init", new AtCommandSequence( {
        """^SLED=2""", // enable STATUS LED (non-persistent)
        """+CFUN=4""", // power up the SIM card
        """^SSET=1""", // enable SIM ready indication
        """^SIND="nitz",1""", // enable Network Identity and Time Zone indication (for now to tests)
        """^SCFG="MEopMode/RingOnData","on"""", // set RingOnData - for some reason this one seems to be volatile?
        """^SCFG="MEopMode/PowerMgmt/LCI","enabled"""" // enable Low Current Indicator (aka SLEEP LED), it's volatile as well
      } ) );

      registerAtCommandSequence( "main", "suspend", new AtCommandSequence( {
        """+CREG=0""", // disable network status updates
        """^SIND="nitz",0""" // disable Network Identity and Time Zone indication
      } ) );

      registerAtCommandSequence( "main", "resume", new AtCommandSequence( {
        """+CREG=2""", // enable network status updates
        """^SIND="nitz",1""" // enable Network Identity and Time Zone indication
      } ) );

      registerAtCommandSequence( "MODEM", "shutdown", new AtCommandSequence( {
          """+CFUN=0""", // put the modem into airplane mode
      } ) );
    }

    protected override void createChannels()
    {
        var transport = modem_transport_spec.create();
        var parser = new FsoGsm.StateBasedAtParser();

        new AtChannel( this, CHANNEL_NAME, transport, parser );

        // we can optionally use second channel to read all URCs
        var modem_urc_access = FsoFramework.theConfig.stringValue( "fsogsm.modem_cinterion_ps8", "modem_urc_access", "" );
        if ( modem_urc_access.length > 0 )
        {
          transport = FsoFramework.TransportSpec.parse( modem_urc_access ).create();
          parser = new FsoGsm.StateBasedAtParser();
          new AtChannel( this, URC_CHANNEL_NAME, transport, parser, true );
        }
    }

    protected override FsoGsm.UnsolicitedResponseHandler createUnsolicitedHandler()
    {
        return new CinterionPS8.UnsolicitedResponseHandler( this );
    }

    protected override void registerCustomMediators( HashMap<Type,Type> mediators )
    {
        CinterionPS8.registerCustomMediators( mediators );
    }

    protected override void registerCustomAtCommands( HashMap<string,FsoGsm.AtCommand> commands )
    {
        CinterionPS8.registerCustomAtCommands( commands );
    }

    protected override FsoGsm.Channel channelForCommand( FsoGsm.AtCommand command, string query )
    {
        // we use only one channel for sending all AT commands
        return channels[ CHANNEL_NAME ];
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
    FsoFramework.theLogger.debug( "fsogsm.cinterion_ps8 fso_factory_function" );
    return "fsogsmd.modem_cinterion_ps8";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    // do not remove this function
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
