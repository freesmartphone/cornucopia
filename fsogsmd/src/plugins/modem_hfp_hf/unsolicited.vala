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

public class HfpHf.UnsolicitedResponseHandler : FsoGsm.AtUnsolicitedResponseHandler
{
    private Indicators _indicators;

    public UnsolicitedResponseHandler( FsoGsm.Modem modem, Indicators indicators )
    {
        base( modem );
        _indicators = indicators;
    }

    public virtual void plusCIEV( string prefix, string rhs )
    {
        var cmd = modem.createAtCommand<PlusCIEV>( "+CIEV" );

        if ( cmd.validateUrc( @"$prefix: $rhs" ) != Constants.AtResponse.VALID )
        {
            logger.warning( @"Received invalid +cmd message $rhs. Please report" );
            return;
        }

        _indicators.update( cmd.value1, cmd.value2 );
    }
}

// vim:ts=4:sw=4:expandtab
