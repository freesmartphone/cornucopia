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

public class Indicators : FsoFramework.AbstractObject
{
    private int[] indexes = new int[Bluetooth.HFP.Indicator.LAST];
    private int[] values = new int[Bluetooth.HFP.Indicator.LAST];

    public bool validate_index( int index, Bluetooth.HFP.Indicator type )
    {
        return indexes[type] == index;
    }

    public void set_index( Bluetooth.HFP.Indicator type, int index )
    {
        indexes[type] = index;
    }

    public void update( Bluetooth.HFP.Indicator type, int value )
    {
        if ( values[type] != value )
            values[type] = value;
    }

    public override string repr()
    {
        return @"<>";
    }
}
