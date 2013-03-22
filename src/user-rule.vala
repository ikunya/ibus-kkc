/* 
 * Copyright (C) 2013 Daiki Ueno <ueno@gnu.org>
 * Copyright (C) 2013 Red Hat, Inc.
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */
public class UserRule : Kkc.Rule {
    Kkc.Keymap[] overrides = new Kkc.Keymap[Kkc.InputMode.LAST];
    string path;

    public UserRule (Kkc.RuleMetadata parent_metadata,
                     string base_dir,
                     string prefix) throws Kkc.RuleParseError {
        var user_rule_path = Path.build_filename (base_dir,
                                                  parent_metadata.name);

        if (!FileUtils.test (user_rule_path, FileTest.IS_DIR)) {
            create_files (parent_metadata,
                          prefix + ":" + parent_metadata.name,
                          user_rule_path);
        }

        var metadata = Kkc.Rule.load_metadata (
            Path.build_filename (user_rule_path, "metadata.json"));
        base (metadata);

        for (int mode = Kkc.InputMode.HIRAGANA;
             mode < Kkc.InputMode.LAST;
             mode++) {
            overrides[mode] = new Kkc.Keymap ();
        }

        path = user_rule_path;
    }

    static void create_files (Kkc.RuleMetadata parent_metadata,
                              string name,
                              string path) {
        DirUtils.create_with_parents (path, 448);
        create_metadata (parent_metadata, name, path);
        create_default (path, "keymap", "default");
        create_default (path, "keymap", "hiragana");
        create_default (path, "keymap", "katakana");
        create_default (path, "keymap", "hankaku-katakana");
        create_default (path, "keymap", "latin");
        create_default (path, "keymap", "wide-latin");
        create_default (path, "keymap", "direct");
        create_default (path, "rom-kana", "default");
    }

    static void create_metadata (Kkc.RuleMetadata parent_metadata,
                                 string name,
                                 string path)
    {
        var builder = new Json.Builder ();
        builder.begin_object ();
        builder.set_member_name ("name");
        builder.add_string_value (name);
        builder.set_member_name ("description");
        builder.add_string_value (parent_metadata.description);
        builder.set_member_name ("filter");
        builder.add_string_value (parent_metadata.filter);
        builder.end_object ();
        var generator = new Json.Generator ();
        generator.set_pretty (true);
        generator.set_root (builder.get_root ());
        try {
            generator.to_file (
                Path.build_filename (path, "metadata.json"));
        } catch (Error e) {
            error ("can't write metadata for user rule %s: %s",
                   name, e.message);
        }
    }

    static void create_default (string path, string type, string name) {
        var type_path = Path.build_filename (path, type);
        DirUtils.create_with_parents (type_path, 448);

        var builder = new Json.Builder ();
        builder.begin_object ();
        builder.set_member_name ("include");
        builder.begin_array ();
        builder.add_string_value ("default/" + name);
        builder.end_array ();
        builder.end_object ();

        var generator = new Json.Generator ();
        generator.set_pretty (true);
        generator.set_root (builder.get_root ());

        var filename = Path.build_filename (type_path, "%s.json".printf (name));
        generator.to_file (filename);
    }

    public void set_override (Kkc.InputMode input_mode,
                              Kkc.KeyEvent event,
                              string? command) {
        overrides[input_mode].set (event, command);
    }

    public void write_override (Kkc.InputMode input_mode) {
        var enum_class = (EnumClass) typeof (Kkc.InputMode).class_ref ();
        var keymap_name = enum_class.get_value (input_mode).value_nick;
        var keymap_path = Path.build_filename (path, "keymap");
        DirUtils.create_with_parents (keymap_path, 448);

        var builder = new Json.Builder ();
        builder.begin_object ();
        builder.set_member_name ("include");
        builder.begin_array ();
        builder.add_string_value ("default/" + keymap_name);
        builder.end_array ();
        builder.set_member_name ("define");
        builder.begin_object ();
        builder.set_member_name ("keymap");
        builder.begin_object ();
        var entries = overrides[input_mode].entries ();
        foreach (var entry in entries) {
            builder.set_member_name (entry.key.to_string ());
            if (entry.command == null)
                builder.add_null_value ();
            else
                builder.add_string_value (entry.command);
        }
        builder.end_object ();
        builder.end_object ();
        builder.end_object ();

        var generator = new Json.Generator ();
        generator.set_pretty (true);
        generator.set_root (builder.get_root ());

        var filename = Path.build_filename (keymap_path,
                                            "%s.json".printf (keymap_name));
        generator.to_file (filename);
    }
}