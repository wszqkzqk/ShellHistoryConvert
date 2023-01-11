shellhistoryconvert_sources = [
  'main.vala',
  'historyconverter.vala',
  'zshhistoryitem.vala',
  'fishhistoryitem.vala'
]

shellhistoryconvert_deps = [
  glib,
  gobject,
  gio
]

executable('shell-history-convert', shellhistoryconvert_sources,
  dependencies: shellhistoryconvert_deps, install: true,
)
