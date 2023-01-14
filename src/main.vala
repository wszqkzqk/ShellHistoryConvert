/* main.vala
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
    [Compact (opaque = true)]
    class CLI {
        static bool show_version = false;
        static string? source_path = null;
        static string? output_path = null;
        static string? mode = null;
        static string? source_type = null;
        static string? output_type = null;
        const OptionEntry[] options = {
            { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
            { "input", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref source_path, "Input FILE, read from the default path if 'input-type' is set", "FILENAME" },
            { "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, ref output_path, "Place output in file FILE", "FILENAME" },
            { "write-mode", 'm', OptionFlags.NONE, OptionArg.STRING, ref mode, "The writing mode of output file, 'a' to append, 'w' to overwrite, default 'a'", "'a', 'w'" },
            { "input-type", 's', OptionFlags.NONE, OptionArg.STRING, ref source_type, "The type of the input file, automatically detected by default", "SHELL" },
            { "output-type", 't', OptionFlags.NONE, OptionArg.STRING, ref output_type, "The type of the output file, automatically detected by default", "SHELL" },
            { null }
        };

        static int main (string[] args) {
            Intl.setlocale ();

            var opt_context = new OptionContext ("A tool to convert shell history between bash, zsh and fish");
            opt_context.set_help_enabled (true);
            opt_context.add_main_entries (options, null);
            try {
                opt_context.parse (ref args);
            } catch (OptionError e) {
                printerr ("error: %s\n", e.message);
                print (opt_context.get_help (true, null));
                return 1;
            }

            if (show_version) {
                print ("Shell History Concert v%s\n", VERSION);
                return 0;
            }

            if (source_path == null) {
                if (source_type != null) {
                    // looking for default paths
                    switch (source_type.down ()) {
                    case "fish":
                    case "f":
                        source_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_data_dir (), "fish", "fish_history");
                        break;
                    case "zsh":
                    case "z":
                        source_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_home_dir (), ".zsh_history");
                        FileStream? zsh_history = FileStream.open (source_path, "r");
                        if (zsh_history == null) {
                            source_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_home_dir (), ".zhistory");
                        }
                        break;
                    case "bash":
                    case "b":
                        source_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_home_dir (), ".bash_history");
                        break;
                    default:
                        printerr ("error: Only bash, zsh, fish are supported now.");
                        return 1;
                    }
                } else {
                    printerr ("error: The input file is missing without the convert type given.\n");
                    return 1;
                }
            }

            if (output_path == null) {
                printerr ("error: The output file is missing!\n");
                return 1;
            }

            if (source_type == null) {
                // automatically detect source_type
                FileStream? file = FileStream.open (source_path, "r");
                if (file == null) {
                    printerr ("The source file does not exists.");
                    return 1;
                }
                char buf[8192];
                if (file.gets (buf) != null) {
                    if ((/^: \d*:\d*;/m).match ((string) buf)) {
                        // zsh
                        source_type = "zsh";
                    } else if ((/^- cmd:/m).match ((string) buf)) {
                        // fish
                        source_type = "fsh";
                    } else {
                        // bash, fallback
                        source_type = "bash";
                    }
                } else {
                    printerr ("error: The source file is unaccessible.");
                    return 1;
                }
                if (unlikely (file.error () != 0)) {
                    file.clearerr ();
                    printerr ("error: The source file is unaccessible.");
                    return 1;
                }
            }

            if (mode != null) {
                if (mode.length > 1) {
                    printerr ("warning: The write mode is invalid, fallback on 'a'");
                    mode = "a";
                } else {
                    switch (mode[0]) {
                    case 'a':
                    case 'w':
                        break;
                    default:
                        printerr ("warning: The write mode is invalid, fallback on 'a'");
                        mode = "a";
                        break;
                    }
                }
            } else {
                mode = "a";
            }

            try {
                var status = convert (
                    output_type, source_type,
                    output_path, source_path,
                    mode
                );
                print (status.to_string ());
                print ("The history convertion from %s to %s is done!\n", source_type, output_type);
            } catch (ConvertError e) {
                printerr ("error: %s", e.message);
                return 1;
            }

            return 0;
        }
    }
}
