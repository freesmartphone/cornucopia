/*
 * (C) 2011 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 */

using GLib;

public errordomain FsoTest.AssertError
{
    UNEXPECTED_VALUE,
    UNEXPECTED_STATE,
}

public class FsoTest.Assert : GLib.Object
{
    private static string typed_value_to_string<T>( T value )
    {
        string result = "";

        Type value_type = typeof(T);
        if ( value_type.is_value_type() )
        {
            if ( value_type.is_a( typeof(string) ) )
                result = @"$((string) value)";
            else if ( value_type.is_a( typeof(int32) ) )
                result = @"$((int32) value)";
            else if ( value_type.is_a( typeof(uint32) ) )
                result = @"$((uint32) value)";
            else if ( value_type.is_a( typeof(int16) ) )
                result = @"$((int16) value)";
            else if ( value_type.is_a( typeof(uint16) ) )
                result = @"$((uint16) value)";
            else if ( value_type.is_a( typeof(int8) ) )
                result = @"$((int8) value)";
            else if ( value_type.is_a( typeof(uint8) ) )
                result = @"$((uint8) value)";
        }

        return result;
    }

    private static void throw_unexpected_value( string info, string message ) throws GLib.Error
    {
        throw new AssertError.UNEXPECTED_VALUE( info +  ( message.length > 0 ? @" : $(message)" : "" ) );
    }

    public static void are_equal<T>( T expected, T actual, string message = "" ) throws GLib.Error
    {
        if ( expected != actual )
        {
            var msg = "$(typed_value_to_string(expected)) != $(typed_value_to_string(actual))";
            throw_unexpected_value<T>( "Actual value is not the same as the expected one: $(msg)", message );
        }
    }

    public static void are_not_equal<T>( T not_expected, T actual, string message = "" ) throws GLib.Error
    {
        if ( not_expected == actual )
        {
            var msg = "$(typed_value_to_string(expected)) == $(typed_value_to_string(actual))";
            throw_unexpected_value( "Actual value is the same as the not expected one: $(msg)", message );
        }
    }

    public static void is_true( bool actual, string message = "" ) throws GLib.Error
    {
        if ( !actual )
            throw_unexpected_value( "Supplied value is not true", message );
    }

    public static void is_false( bool actual, string message = "" ) throws GLib.Error
    {
        if ( actual )
            throw_unexpected_value( "Supplied value is not false", message );
    }

    public static void fail( string message ) throws GLib.Error
    {
        throw new AssertError.UNEXPECTED_STATE( message );
    }

    public static void should_throw_async( AsyncBegin fbegin, AsyncFinish ffinish, string domain, string message = "" ) throws GLib.Error
    {
        try
        {
            if ( !wait_for_async( 200, fbegin, ffinish ) )
                throw_unexpected_value( "Execution of async method didn't returns the expected value", message );
        }
        catch ( GLib.Error err )
        {
            if ( err.domain.to_string() != domain )
                throw_unexpected_value( @"Didn't receive the expected exception of type $domain", message );
            return;
        }

        throw new AssertError.UNEXPECTED_STATE( @"Function didn't throw expected exception" );
    }
}

// vim:ts=4:sw=4:expandtab
