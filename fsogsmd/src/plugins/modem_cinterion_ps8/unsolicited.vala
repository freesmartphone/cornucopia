/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2014 Sebastian Krzyszkowiak <dos@dosowisko.net>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using FsoGsm;
using Gee;

public class CinterionPS8.UnsolicitedResponseHandler : FsoGsm.AtUnsolicitedResponseHandler
{

  public UnsolicitedResponseHandler( FsoGsm.Modem modem )
  {
    base( modem );

    registerUrc( "^SYSSTART", modemReady );
    registerUrc( "^SYSSTART AIRPLANE MODE", modemReady );
  }

  public virtual void modemReady( string prefix, string rhs )
  {
    assert( modem.logger.info( @"Modem ready: $prefix" ) );
  }

}

// vim:ts=4:sw=4:expandtab
