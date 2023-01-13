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

    public Status convert (string output_type, string source_type,
                         string output_path, string source_path,
                         string mode = "a") throws ConvertError {
        HistoryEntry[] history_items;
        Status status = {0, 0};
        switch (source_type.down ()) {
        case "fish":
        case "f":
            source_type = "fish";
            var parser = new FishParser (source_path);
            history_items = parser.parse ();
            status = parser.status;
            break;
        case "zsh":
        case "z":
            source_type = "zsh";
            var parser = new ZshOrBashParser (source_path);
            history_items = parser.parse ();
            status = parser.status;
            break;
        case "bash":
        case "b":
            source_type = "bash";
            var parser = new ZshOrBashParser (source_path);
            history_items = parser.parse ();
            status = parser.status;
            break;
        default:
            throw new ConvertError.OPERATOR_ERROR ("Only bash, zsh, fish are supported now.");
        }

        var output_file = FileStream.open (output_path, mode);
        if (output_file == null) {
            throw new ConvertError.NO_LEGAL_SOURCE_FILE ("Cannot open the source file.");
        }
        switch (output_type.down ()) {
        case "fish":
        case "f":
            foreach (var item in history_items) {
                output_file.puts (item.to_fish ());
            }
            break;
        case "zsh":
        case "z":
            foreach (var item in history_items) {
                output_file.puts (item.to_zsh ());
            }
            break;
        case "bash":
        case "b":
            foreach (var item in history_items) {
                output_file.puts (item.to_bash ());
            }
            break;
        default:
            throw new ConvertError.OPERATOR_ERROR ("Only bash, zsh, fish are supported now.");
        }

        if (unlikely (output_file.error () != 0)) {
            output_file.clearerr ();
            throw new ConvertError.OUTPUT_FILE_ACCESS ("Cannot write to the output path.");
        }

        return status;
    }
}
