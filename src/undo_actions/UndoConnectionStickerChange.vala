/*
* Copyright (c) 2018 (https://github.com/phase1geo/Minder)
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
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;

public class UndoConnectionStickerChange : UndoItem {

  private Connection _conn;
  private string     _name;

  /* Default constructor */
  public UndoConnectionStickerChange( Connection conn, string orig_name ) {
    base( _( "change connection sticker" ) );
    _conn = conn;
    _name = orig_name;
  }

  private void toggle( DrawArea da ) {
    var name = _conn.sticker;
    _conn.sticker = _name;
    _name = name;
    da.queue_draw();
    da.changed();
  }

  /* Performs an undo operation for this data */
  public override void undo( DrawArea da ) {
    toggle( da );
  }

  /* Performs a redo operation */
  public override void redo( DrawArea da ) {
    toggle( da );
  }

}
