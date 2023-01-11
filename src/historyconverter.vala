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
        NO_LEGAL_SOURCE_FILE
    }

    class HistoryConverter: Object {
        string source_path;
        string output_path;
        FileStream source_file;
        FileStream output_file;
        Operation operation;
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

        public enum Operation {
            F_TO_Z,
            Z_TO_F,
            F_TO_B,
            Z_TO_B,
        }

        public HistoryConverter (   Operation operation, string output_path,
                                    string source_path, string mode = "a") {
            this.operation = operation;
            this.mode = mode;
            Object (
                output: output_path,
                source: source_path
            );
        }

        string[] read_source_lines () throws ConvertError {
            string[] lines = {};
            string? line;
            if (source_file == null) {
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is not set or not exists.");
            }
            while ((line = source_file.read_line ()) != null) {
                lines += line;
            }
            if (unlikely (source_file.error () != 0)) {
                source_file.clearerr ();
                throw new ConvertError.NO_LEGAL_SOURCE_FILE ("The source file is unaccessible.");
            }
            return lines;
        }

        string fish_to_zsh () throws ConvertError {
            var final_builder = new StringBuilder ();
            var lines = read_source_lines ();
            int index = 0;
            var cmd_re = /^- cmd: (.*)/;
            var time_re = /^  when: (\d*)/;
            string? time = null;
            MatchInfo cmd_match;
            MatchInfo time_match;
            while (index < lines.length) {
                var line = lines[index];
                if (cmd_re.match (line, 0, out cmd_match)) {
                    var cmd_list = ((cmd_match.fetch (1)).compress ()).split ("\n");
                    if (index < lines.length - 1) {
                        index += 1;
                        line = lines[index];
                        if (time_re.match (line, 0, out time_match)) {
                            time = time_match.fetch (1);
                        }
                    }
                    if (unlikely (time == null)) {
                        time = (get_real_time () / 1000000).to_string ();
                    }
                    var zsh_item = new ZshHistoryItem (time);
                    foreach (var i in cmd_list) {
                        zsh_item.add_cmd_line (i);
                    }
                    final_builder.append (zsh_item.content);
                }
                index += 1;
            }
            return final_builder.str;
        }

        string zsh_to_fish () throws Error {

        }

        string fish_to_bash () throws Error {

        }

        string zsh_to_bash () throws Error {

        }

        public void run () throws Error {
            string converted;
            switch (operation) {
            case Operation.F_TO_Z:
                converted = fish_to_zsh ();
                break;
            case Operation.Z_TO_F:
                converted = zsh_to_fish ();
                break;
            case Operation.F_TO_B:
                converted = fish_to_bash ();
                break;
            case Operation.Z_TO_B:
                converted = zsh_to_bash ();
                break;
            default:
                throw new ConvertError.OPERATOR_ERROR ("The convert operation is unknown.");
            }
        }
    }
}
