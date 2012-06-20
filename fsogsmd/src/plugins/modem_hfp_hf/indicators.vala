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
    private int[] indexes = new int[Constants.Indicator.LAST];
    private int[] values = new int[Constants.Indicator.LAST];

    public bool validate_index( int index, Constants.Indicator type )
    {
        return indexes[type] == index;
    }

    public void set_index( Constants.Indicator type, int index )
    {
        indexes[type] = index;
    }

    public int get_value( Constants.Indicator type )
    {
        return values[type];
    }

    public void update( int index, int value )
    {
        var type = Constants.Indicator.UNKNOWN;

        for ( var n = 0; n < indexes.length; n++ )
        {
            if ( indexes[n] == index )
            {
                type = (Constants.Indicator) n;
                break;
            }
        }

        if ( type == Constants.Indicator.UNKNOWN || type == Constants.Indicator.LAST )
            return;

        if ( values[type] != value )
        {
            values[type] = value;
            indicator_changed( type, values[type] );
        }
    }

    public override string repr()
    {
        return @"<>";
    }

    public signal void indicator_changed( Constants.Indicator type, int value );
}
