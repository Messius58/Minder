/*
* Copyright (c) 2020 (https://github.com/Messius58/Minder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Branciat Jérôme
*/

using Gtk;
using GLib;
using Gee;
using Granite.Widgets;

public class NodeData {
    public string id;
    public string pathfile;
    public string node_text;
    public string node_note;
}

public class FileInspector : Box {
    
    private Gtk.TreeView                _view;
    private TreeStore                   _tree;
    private string                      default_path = "";
    private ScrolledWindow              _sw;
    private MainWindow                  _win;
    private GLib.Settings               _settings;
    private HashTable<string, bool>     _files_loaded;

    public string directory {
        get {
            return default_path;
        }
        set {
            default_path = value;
        }
    }

    public FileInspector( MainWindow win, GLib.Settings settings ) {
        Object( orientation:Orientation.VERTICAL, spacing:10 );
        _settings = settings;
        _win = win;
        _win.file_event.connect(file_event);
        _win.tab_event.connect(highlight_tree);
        _win.preference_changed.connect(settings_changed);
        directory = settings.get_string( "default-directory" );
        _files_loaded = new HashTable<string, bool>(str_hash, str_equal);

        init_tree();

        show_all();
    }

    /*
        Create the TreeView and TreeStore
    */
    private void init_tree() {
        _tree = new TreeStore(3, typeof(string), typeof(string), typeof(string));
        _view  = new TreeView();
        _sw = new ScrolledWindow( null, null );
        _sw.min_content_width  = 300;
        _sw.min_content_height = 100;
        _sw.add( _view );
        pack_start( _sw,  true,  true );

        Gtk.TreeViewColumn col  = new Gtk.TreeViewColumn();
        CellRendererText renderer = new CellRendererText();
        renderer.set_property("foreground-set",true);
        col.pack_start (renderer, true);
        col.set_title(create_title());
        col.add_attribute(renderer, "text", 0);
        col.add_attribute(renderer, "foreground", 2);
        col.set_clickable(true);
        col.set_sort_indicator(true);
        col.set_sort_column_id(0);
        _view.set_model(_tree);
        _view.append_column(col);
        _view.activate_on_single_click = true;
        _view.headers_visible = true;
        _view.enable_search = true;
        _view.row_activated.connect( on_row_activated );

        load_files(null, default_path);
    }

    /* Loading the files which are localized in the default directory */
    private void load_files( TreeIter? root, string dir_name ) {
        try {
            if(!FileUtils.test(dir_name, FileTest.IS_DIR))
            { return; }
            GLib.Dir dir = GLib.Dir.open(dir_name);
            string? name = null;
            TreeIter child_folder;
            _tree.clear();
            while ((name = dir.read_name ()) != null) {
                string path = Path.build_filename (dir_name, name);
                if (FileUtils.test (path, FileTest.IS_REGULAR) && name.has_suffix(".minder")) {
                    _tree.append(out child_folder, root);
                    _tree.set(child_folder, 0, name, 1, dir_name, -1);
                }
    
               /*if (FileUtils.test (path, FileTest.IS_DIR)) {
                    _tree.prepend(out child_folder, root);
                    _tree.set(child_folder, 0, name, -1);
                    load_files(child_folder, Path.build_filename (path, name));
                }*/
            }
            
        } catch (GLib.FileError fe) {
            printerr("FileInspector Load files : " + fe.message);
        }
    }

    public GLib.List<NodeData> search(string pattern) {
        GLib.List<NodeData> list = new GLib.List<NodeData>();
        try {
            TreeIter it;
            _tree.get_iter_first(out it);
            do {
                string filename = "", pathfile = "";
                _tree.get(it, 0, &filename, 1, &pathfile, -1);
                string complete_name = Path.build_filename(pathfile, filename);
                Xml.Doc* doc = Xml.Parser.parse_file( complete_name );
                if (doc != null) {
                    Xml.XPath.Context cntx = new Xml.XPath.Context(doc);
                    Xml.XPath.Object* res  = cntx.eval_expression("//node[@id]");
                    for (int i = 0; i < res->nodesetval->length (); i++) {
                        Xml.Node* node = res->nodesetval->item (i);
                        string id = node->get_prop("id");
                        string text = "";
                        string note = "";
                        for( Xml.Node* node_child = node->children; node_child != null; node_child = node_child->next ) {
                            if(node_child->name == "nodename") {
                                text = Utils.match_string(pattern, node_child->first_element_child()->get_prop("data"));
                            }
                            if(node_child->name == "nodenote") {
                                note = Utils.match_string(pattern, node_child->get_content());
                            }
                        }
                        if(text != "" || note != "") {
                            list.append(new NodeData() {
                                id        = id,
                                pathfile  = complete_name,
                                node_text = text,
                                node_note = note
                            });
                        }
                    }
                    delete res;
                    delete doc;        
                }
            }while(_tree.iter_next(ref it));
        }catch (Error e) {
            printerr("error in function search / inspector" + e.message);
        }
        return list;
    }

  /* Grabs input focus on the first UI element */
  public void grab_first() {
    _view.grab_focus();
  }

  private string create_title() {
    int idx = default_path.length;
    string prefix = _("Directory : ");
    if(idx > 30) {
        unichar  c = 0;
        int i = 0;
        prefix += "...";
        while (default_path.get_prev_char(ref idx, out c) && i < 30) {
          i++;
        }
      }
      return prefix + default_path.substring(idx);
  }

  /**********************
        SIGNAL HANDLER
  **********************/

  /* Get the selected file and open it */
  private void on_row_activated( TreePath path, TreeViewColumn col ) {
    TreeIter iter;
    string filename = "", pathfile = "";
    _tree.get_iter(out iter, path);
    _tree.get(iter, 0, &filename, 1, &pathfile, -1);
    if(!_files_loaded.contains(filename)){
        _win.open_file(Path.build_filename(pathfile, filename));
        _files_loaded.insert(filename, true);
    }else{
        _win.action_change_tab(filename);
    }
}

  /* On file loaded : highlight the selected file */
  private void file_event(string fname) {
      highlight_tree(fname, TabReason.LOAD);
  }

  public bool file_is_loading(string pathfile) {
      string filename = Path.get_basename(pathfile);
      if(_files_loaded.contains(filename)) {
          return _files_loaded.get(filename);
      }
      return false;
  }

  private void settings_changed() {
      default_path = _settings.get_string("default-directory");
      load_files(null, default_path);
      _view.get_column(0).set_title(create_title());
  }

  /* 
      on tab event : update the text color of the file in the treebox 
  */
  private void highlight_tree(string fname, TabReason reason) {
    string basename = Path.get_basename(fname);
    string filename = "";
    TreeIter it;
    _tree.get_iter_first(out it);
    if(it.stamp == 0)
    { return; }
    do{
        _tree.get(it, 0, &filename, -1);
        if(basename == filename){
            break;
        }
    }while (_tree.iter_next(ref it));
    if(it.stamp != 0){
        TreeViewColumn col = _view.get_column(0);
        switch (reason) {
            case TabReason.LOAD:
                _tree.set(it, 2, "#ff5733", -1);
                if(!_files_loaded.contains(filename)) {
                    _files_loaded.insert(filename, true);
                }else{
                    _files_loaded.set(filename, true);
                }
                _view.set_cursor(_tree.get_path(it), col, true);
            break;
            case TabReason.SHOW:
            _tree.set(it, 2, "#ff5733", -1);
            _view.set_cursor(_tree.get_path(it), col, true);
            break;
            case TabReason.CLOSE:
                _tree.set_value(it, 2, "#FFFFFF");
                if(_files_loaded.contains(filename)) {
                    _files_loaded.set(filename, false);
                }
            break;
            default:
            break;
        }
    }
  }
}