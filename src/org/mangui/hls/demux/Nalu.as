/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
 package org.mangui.hls.demux {

    import flash.utils.ByteArray;
    CONFIG::LOGGING {
    import org.mangui.hls.HLSSettings;
    import org.mangui.hls.utils.Log;
    }

    /** Constants and utilities for the H264 video format. **/
    public class Nalu {

        private static var _audNalu : ByteArray;
        // static initializer
        {
            _audNalu = new ByteArray();
            _audNalu.length = 2;
            _audNalu.writeByte(0x09);
            _audNalu.writeByte(0xF0);
        };


        /** Return an array with NAL delimiter indexes. **/
        public static function getNALU(nalu : ByteArray, position : uint) : Vector.<VideoFrame> {
            var units : Vector.<VideoFrame> = new Vector.<VideoFrame>();
            var unit_start : int;
            var unit_type : int;
            var unit_header : int;
            var aud_found : Boolean = false;
            // Loop through data to find NAL startcodes.
            var window : uint = 0;
            nalu.position = position;
            while (nalu.bytesAvailable > 4) {
                window = nalu.readUnsignedInt();
                // Match four-byte startcodes
                if ((window & 0xFFFFFFFF) == 0x01) {
                    // push previous NAL unit if new start delimiter found, dont push unit with type = 0
                    if (unit_start && unit_type) {
                        units.push(new VideoFrame(unit_header, nalu.position - 4 - unit_start, unit_start, unit_type));
                    }
                    unit_header = 4;
                    unit_start = nalu.position;
                    unit_type = nalu.readByte() & 0x1F;
                    if(unit_type ==9) {
                        aud_found = true;
                    }
                    /* if AUD already found and newly found unit is NDR or IDR,
                        stop parsing here and consider that this IDR/NDR is the last NAL unit
                        breaking the loop here is done for optimization purpose, as NAL parsing is time consuming ...
                     */
                    if (aud_found && (unit_type == 1 || unit_type == 5)) {
                        break;
                    }
                    // Match three-byte startcodes
                } else if ((window & 0xFFFFFF00) == 0x100) {
                    // push previous NAL unit if new start delimiter found, dont push unit with type = 0
                    if (unit_start && unit_type) {
                        units.push(new VideoFrame(unit_header, nalu.position - 4 - unit_start, unit_start, unit_type));
                    }
                    nalu.position--;
                    unit_header = 3;
                    unit_start = nalu.position;
                    unit_type = nalu.readByte() & 0x1F;
                    if(unit_type ==9) {
                        aud_found = true;
                    }
                    /* if AUD already found and newly found unit is NDR or IDR,
                        stop parsing here and consider that this IDR/NDR is the last NAL unit
                        breaking the loop here is done for optimization purpose, as NAL parsing is time consuming ...
                     */
                    if (aud_found && (unit_type == 1 || unit_type == 5)) {
                        break;
                    }
                } else {
                    nalu.position -= 3;
                }
            }
            // Append the last NAL to the array.
            if (unit_start) {
                units.push(new VideoFrame(unit_header, nalu.length - unit_start, unit_start, unit_type));
            }
            // Reset position and return results.
            CONFIG::LOGGING {
                if (HLSSettings.logDebug2) {
                    /** H264 NAL unit names. **/
                    const NAMES : Array = ['Unspecified',// 0
                    'NDR',                          // 1
                    'Partition A',                  // 2
                    'Partition B',                  // 3
                    'Partition C',                  // 4
                    'IDR',                          // 5
                    'SEI',                          // 6
                    'SPS',                          // 7
                    'PPS',                          // 8
                    'AUD',                          // 9
                    'End of Sequence',              // 10
                    'End of Stream',                // 11
                    'Filler Data'// 12
                    ];
                    if (units.length) {
                        var txt : String = "AVC: ";
                        for (var i : int = 0; i < units.length; i++) {
                            txt += NAMES[units[i].type] + ","; //+ ":" + units[i].length
                        }
                        Log.debug2(txt.substr(0,txt.length-1) + " slices");
                    } else {
                        Log.debug2('AVC: no NALU slices found');
                    }
                }
            }
            nalu.position = position;
            return units;
        };

        public static function get AUD():ByteArray {
            return _audNalu;
        }
    }
}
