/* bashhistoryitem.vala
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
    class BashHistoryItem {
        StringBuilder builder;
        string val;
        public string content {
            get {
                val = builder.str + "\n";
                return val;
            }
        }

        public BashHistoryItem (string? cmd = null) {
            if (cmd == null) {
                builder = new StringBuilder ();
            } else {
                builder = new StringBuilder (cmd);
            }
        }

        public void add_cmd (string cmd) {
            builder.append ("; ");
            builder.append (cmd);
        }
    }
} 