/* historyparsers.vala
 *
 * Copyright 2023 周 乾康 <wszqkzqk@stu.pku.edu.cn>
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
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

namespace Converter {
    public struct Status {
        uint success;
        uint failure;

        public string to_string () {
            return "Totla entries: %u\nSuccess: %u\nFailure: %u\n".printf (success+failure, success, failure);
        }
    }

    public struct HistoryEntry {
        string time;
        string[] cmd_list;

        public string? to_fish () {
            if (unlikely (cmd_list == null)) {
                return null;
            } else if (unlikely (time == null)) {
                time = (get_real_time () / 1000000).to_string ();
            }
            var cmd_builder = new StringBuilder ();
            for (int i = 0; i < cmd_list.length; i += 1) {
                if (i != 0) {
                    cmd_builder.append ("\\n");
                }
                cmd_builder.append (cmd_list[i]);
            }
            return "- cmd: %s\n  when: %s\n".printf (cmd_builder.str, time);
        }

        public string? to_zsh () {
            if (unlikely (cmd_list == null)) {
                return null;
            } else if (unlikely (time == null)) {
                time = (get_real_time () / 1000000).to_string ();
            }
            var builder = new StringBuilder (": %s:0;".printf (time));
            for (int i = 0; i < cmd_list.length; i += 1) {
                if (i != 0) {
                    builder.append ("\\\n");
                }
                builder.append (cmd_list[i]);
            }
            builder.append_c ('\n');
            return builder.str;
        }

        public string? to_bash () {
            if (unlikely (cmd_list == null)) {
                return null;
            }
            var builder = new StringBuilder ();
            for (int i = 0; i < cmd_list.length; i += 1) {
                if (i != 0) {
                    builder.append ("; ");
                }
                builder.append (cmd_list[i]);
            }
            builder.append_c ('\n');
            return builder.str;
        }
    }

    public abstract class BasicParser {
        protected uint success = 0;
        protected uint failure = 0;
        protected string? source_path;
        protected FileStream source_file;
        public string? source {
            get {
                return source_path;
            }
            protected set {
                source_file = FileStream.open (value, "r");
                if (source_file == null) {
                    critical ("Failed to open the input file.");
                    source_path = null;
                } else {
                    source_path = value;
                }
            }
        }
        public Status status {
            get {
                return {success, failure};
            }
        }

        public abstract void parse (out GenericArray<HistoryEntry?> history_items) throws ConvertError;
    }

    class FishParser: BasicParser {
        static Regex? cmd_re = null;
        static Regex? time_re = null;

        public FishParser (string source) {
            if (cmd_re == null) {
                cmd_re = /^- cmd: (.*)/;
            }
            if (time_re == null) {
                time_re = /^  when: (\d*)/;
            }
            this.source = source;
        }

        public override void parse (out GenericArray<HistoryEntry?> history_items) throws ConvertError {
            if (source_file == null) {
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is not set or does not exist.");
            }
            source_file.rewind ();
            history_items = new GenericArray<HistoryEntry?> ();
            string? line = null;
            string? time = null;
            while ((line = source_file.read_line ()) != null) {
                MatchInfo cmd_match;
                MatchInfo time_match;
                if (cmd_re.match (line, 0, out cmd_match)) {
                    success += 1;
                    var cmd_list = ((cmd_match.fetch (1)).compress ()).split ("\n");
                    if (likely ((line = source_file.read_line ()) != null)) {
                        if (time_re.match (line, 0, out time_match)) {
                            time = time_match.fetch (1);
                        }
                    }
                    if (unlikely (time == null)) {
                        time = (get_real_time () / 1000000).to_string ();
                    }
                    HistoryEntry h_item = {time, cmd_list};
                    history_items.add (h_item);
                }
            }
            if (unlikely (source_file.error () != 0)) {
                source_file.clearerr ();
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is unaccessible.");
            }
        }
    }

    class ZshOrBashParser: BasicParser {
        static Regex? his_re = null;
        static Regex? multiline_re = null;

        public ZshOrBashParser (string source) {
            if (his_re == null) {
                his_re = /^: (?<time>\d*):\d*;(?<cmd>.*?)(?<backslashs>\\*?)$/;
            }
            if (multiline_re == null) {
                multiline_re = /^(?<cmd>.*?)(?<backslashs>\\*?)$/;
            }
            this.source = source;
        }

        public override void parse (out GenericArray<HistoryEntry?> history_items) throws ConvertError {
            if (source_file == null) {
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is not set or does not exist.");
            }
            source_file.rewind ();
            string? line;
            string? time = null;
            history_items = new GenericArray<HistoryEntry?> ();
            string[] cmd_list = {};
            bool in_multiline_cmd = false;
            while ((line = source_file.read_line ()) != null) {
                MatchInfo history_match;
                MatchInfo multiline_match;
                if (his_re.match (line, 0, out history_match)) {
                    if (unlikely (in_multiline_cmd)) {
                        // Error in zsh history:
                        // The last line ends with `\` but the nex line is a new history item
                        // Save the item first
                        HistoryEntry h_item = {time, cmd_list};
                        history_items.add (h_item);
                        in_multiline_cmd = false;
                    }
                    
                    cmd_list = {};
                    time = history_match.fetch_named ("time");
                    var backslashs = history_match.fetch_named ("backslashs");
                    if (backslashs.length == 0) {
                        cmd_list += history_match.fetch_named ("cmd");
                    } else if (backslashs.length % 2 == 0) {
                        cmd_list += (history_match.fetch_named ("cmd") + backslashs);
                    } else {
                        cmd_list += (history_match.fetch_named ("cmd") + backslashs[0:-1]);
                        in_multiline_cmd = true;
                    }
                } else {
                    // 1. Simplified zsh history or bash history
                    // 2. multiline cmd, need to read until the cmd ends
                    if (time == null) {
                        time = (get_real_time () / 1000000).to_string ();
                    }
                    if (!in_multiline_cmd) {
                        // Simplified zsh history or bash history
                        cmd_list = {};
                    } // else: multiline cmd, need to read until the cmd ends
                    multiline_re.match (line, 0, out multiline_match);
                    var backslashs = multiline_match.fetch_named ("backslashs");
                    var cmd = multiline_match.fetch_named ("cmd");
                    if (cmd == null) {
                        failure += 1;
                        continue;
                    }
                    if (backslashs == null || backslashs.length == 0) {
                        cmd_list += cmd;
                        in_multiline_cmd = false;
                    } else if (backslashs.length % 2 == 0) {
                        cmd_list += cmd + backslashs;
                        in_multiline_cmd = false;
                    } else {
                        cmd_list += cmd + backslashs[0:-1];
                        in_multiline_cmd = true;
                    }
                }

                if (!in_multiline_cmd) {
                    // Completed, store the result
                    success += 1;
                    HistoryEntry h_item = {time, cmd_list};
                    history_items.add (h_item);
                }
            }
            if (unlikely (source_file.error () != 0)) {
                source_file.clearerr ();
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is unaccessible.");
            }
        }
    }
}
