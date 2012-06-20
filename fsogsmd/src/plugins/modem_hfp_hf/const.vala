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

namespace Bluetooth.HFP
{
    public enum Version
    {
        VERSION_1_5 = 0x0105,
        VERSION_LATEST = 0x0105,
    }

    public enum Indicator
    {
        UNKNOWN = -1,
        SERVICE = 0,
        CALL = 1,
        CALLSETUP = 2,
        CALLHELD = 3,
        SIGNAL = 4,
        ROAM = 5,
        BATTCHG = 6,
        LAST = 7
    }

    public Indicator indicator_from_string( string str )
    {
        var result = Indicator.UNKNOWN;

        switch ( str )
        {
            case "service":
                result = Indicator.SERVICE;
                break;
            case "call":
                result = Indicator.CALL;
                break;
            case "callsetup":
                result = Indicator.CALLSETUP;
                break;
            case "callheld":
                result = Indicator.CALLHELD;
                break;
            case "signal":
                result = Indicator.SIGNAL;
                break;
            case "battchg":
                result = Indicator.BATTCHG;
                break;
        }

        return result;
    }

    /* HFP HF/AG supported features bitmap. Bluetooth HFP 1.6 spec page 88 */
    public enum Feature
    {
        HF_ECNR = 0x1,
        HF_3WAY = 0x2,
        HF_CLIP = 0x4,
        HF_VOICE_RECOGNITION = 0x8,
        HF_REMOTE_VOLUME_CONTROL = 0x10,
        HF_ENHANCED_CALL_STATUS = 0x20,
        HF_ENHANCED_CALL_CONTROL = 0x40,
        HF_CODEC_NEGOTIATION = 0x80,

        AG_3WAY = 0x1,
        AG_ECNR = 0x2,
        AG_VOICE_RECOG = 0x4,
        AG_IN_BAND_RING_TONE = 0x8,
        AG_ATTACH_VOICE_TAG = 0x10,
        AG_REJECT_CALL = 0x20,
        AG_ENHANCED_CALL_STATUS = 0x40,
        AG_ENHANCED_CALL_CONTROL = 0x80,
        AG_EXTENDED_RES_CODE = 0x100,
        AG_CODEC_NEGOTIATION = 0x200,
    }
}

// vim:ts=4:sw=4:expandtab
