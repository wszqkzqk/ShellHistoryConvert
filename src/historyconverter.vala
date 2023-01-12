/* historyconverter.vala
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
    public errordomain ConvertError {
        OPERATOR_ERROR,
        NO_LEGAL_SOURCE_FILE,
        NO_OUTPUT_FILE,
        OUTPUT_FILE_ACCESS
    }

    public class HistoryConverter: Object {
        HistoryType source_type;
        HistoryType output_type;
        string source_path;
        string output_path;
        FileStream source_file;
        FileStream output_file;
        HistoryItem[] history_items;
        public string mode;

        public string source {
            get {
                return source_path;
            }
            construct set {
                source_file = FileStream.open (value, "r");
                source_path = (source_file != null) ? value : null;
            }
        }
        public string output {
            get {
                return output_path;
            }
            construct set {
                output_file = FileStream.open (value, mode);
                output_path = (output_file != null) ? value : null;
            }
        }

        public enum HistoryType {
            FISH,
            ZSH,
            BASH;

            public static HistoryType parse (string option) throws ConvertError {
                switch (option.down ()) {
                case "fish":
                case "f":
                    return HistoryType.FISH;
                case "zsh":
                case "z":
                    return HistoryType.ZSH;
                case "bash":
                case "b":
                    return HistoryType.BASH;
                default:
                    throw new ConvertError.OPERATOR_ERROR ("Only bash, zsh, fish are supported now.");
                }
            }
        }

        struct HistoryItem {
            string time;
            string[] cmd_list;
        }

        public HistoryConverter (   HistoryType output_type, HistoryType source_type,
                                    string output_path, string source_path,
                                    string? mode = null) {
            this.output_type = output_type;
            this.source_type = source_type;
            this.mode = mode ?? "a";
            Object (
                output: output_path,
                source: source_path
            );
        }

        void parse_fish () throws ConvertError {
            if (source_file == null) {
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is not set or 
does not exist.");
            }

            var cmd_re = /^- cmd: (.*)/;
            var time_re = /^  when: (\d*)/;
            string? time = null;
            MatchInfo cmd_match;
            MatchInfo time_match;
            history_items = {};

            string? line;
            while ((line = source_file.read_line ()) != null) {
                if (cmd_re.match (line, 0, out cmd_match)) {
                    var cmd_list = ((cmd_match.fetch (1)).compress ()).split ("\n");
                    if (likely ((line = source_file.read_line ()) != null)) {
                        if (time_re.match (line, 0, out time_match)) {
                            time = time_match.fetch (1);
                        }
                    }
                    if (unlikely (time == null)) {
                        time = (get_real_time () / 1000000).to_string ();
                    }
                    HistoryItem h_item = {time, cmd_list};
                    history_items += h_item;
                }
            }
            if (unlikely (source_file.error () != 0)) {
                source_file.clearerr ();
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is unaccessible.");
            }
        }

        void parse_zsh_or_bash () throws ConvertError {
            if (source_file == null) {
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is not set or 
does not exist.");
            }

            var his_re = /^: (?<time>\d*):\d*;(?<cmd>.*?)(?<backslashs>\\*?)$/;
            var mutiline_re = /^(?<cmd>.*?)(?<backslashs>\\*?)&/;

            string? time = null;
            history_items = {};
            string? line;
            string[] cmd_list = {};
            bool in_mutiline_cmd = false;
            while ((line = source_file.read_line ()) != null) {
                MatchInfo history_match;
                MatchInfo mutiline_match;
                if (his_re.match (line, 0, out history_match)) {
                    if (unlikely (in_mutiline_cmd)) {
                        // Error in zsh history:
                        // The last line ends with `\` but the nex line is a new history item
                        // Save the item first
                        HistoryItem h_item = {time, cmd_list};
                        history_items += h_item;
                        in_mutiline_cmd = false;
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
                        in_mutiline_cmd = true;
                    }
                } else {
                    // 1. Simplified zsh history or bash history
                    // 2. mutiline cmd, need to read until the cmd ends
                    if (time == null) {
                        time = (get_real_time () / 1000000).to_string ();
                    }
                    if (!in_mutiline_cmd) {
                        // Simplified zsh history or bash history
                        cmd_list = {};
                    } // else: mutiline cmd, need to read until the cmd ends
                    mutiline_re.match (line, 0, out mutiline_match);
                    var backslashs = mutiline_match.fetch_named ("backslashs");
                    if (backslashs.length == 0) {
                        cmd_list += mutiline_match.fetch_named ("cmd");
                        in_mutiline_cmd = false;
                    } else if (backslashs.length % 2 == 0) {
                        cmd_list += (mutiline_match.fetch_named ("cmd") + backslashs);
                        in_mutiline_cmd = false;
                    } else {
                        cmd_list += (mutiline_match.fetch_named ("cmd") + backslashs[0:-1]);
                        in_mutiline_cmd = true;
                    }
                }

                if (!in_mutiline_cmd) {
                    // Completed, store the result
                    HistoryItem h_item = {time, cmd_list};
                    history_items += h_item;
                }
            }
            if (unlikely (source_file.error () != 0)) {
                source_file.clearerr ();
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is unaccessible.");
            }
        }

        void write_fish () throws ConvertError {
            if (output_file == null) {
                throw new ConvertError.NO_OUTPUT_FILE ("The output path has not set.");
            }

            foreach (var item in history_items) {
                var fish_item = new FishHistoryItem (item.time);
                foreach (var cmd in item.cmd_list) {
                    fish_item.add_cmd (cmd);
                }
                output_file.puts (fish_item.content);
            }

            if (unlikely (output_file.error () != 0)) {
                output_file.clearerr ();
                throw new ConvertError.OUTPUT_FILE_ACCESS ("Cannot write to the output path.");
            }
        }
        
        void write_zsh () throws ConvertError {
            if (output_file == null) {
                throw new ConvertError.NO_OUTPUT_FILE ("The output path has not set.");
            }

            foreach (var item in history_items) {
                var zsh_item = new ZshHistoryItem (item.time);
                foreach (var cmd in item.cmd_list) {
                    zsh_item.add_cmd (cmd);
                }
                output_file.puts (zsh_item.content);
            }

            if (unlikely (output_file.error () != 0)) {
                output_file.clearerr ();
                throw new ConvertError.OUTPUT_FILE_ACCESS ("Cannot write to the output path.");
            }
        }

        void write_bash () throws ConvertError {
            if (output_file == null) {
                throw new ConvertError.NO_OUTPUT_FILE ("The output path has not set.");
            }

            foreach (var item in history_items) {
                var bash_item = new BashHistoryItem ();
                foreach (var cmd in item.cmd_list) {
                    bash_item.add_cmd (cmd);
                }
                output_file.puts (bash_item.content);
            }

            if (unlikely (output_file.error () != 0)) {
                output_file.clearerr ();
                throw new ConvertError.OUTPUT_FILE_ACCESS ("Cannot write to the output path.");
            }
        }

        public void run () throws ConvertError {
            switch (source_type) {
            case HistoryType.FISH:
                parse_fish ();
                break;
            case HistoryType.ZSH:
            case HistoryType.BASH:
                parse_zsh_or_bash ();
                break;
            default:
                throw new ConvertError.OPERATOR_ERROR ("Only bash, zsh, fish are supported now.");
            }

            switch (output_type) {
            case HistoryType.FISH:
                write_fish ();
                break;
            case HistoryType.ZSH:
                write_zsh ();
                break;
            case HistoryType.BASH:
                write_bash ();
                break;
            default:
                throw new ConvertError.OPERATOR_ERROR ("Only bash, zsh, fish are supported now.");
            }
        }
    }
}
