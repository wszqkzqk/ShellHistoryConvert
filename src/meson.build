basic_sources = [
  'main.vala',
  'historyconverter.vala',
  'zshhistoryitem.vala',
  'fishhistoryitem.vala',
  'bashhistoryitem.vala'
]

basic_deps = [
  glib,
  gobject,
  gio
]

executable('shell-history-convert', basic_sources,
  dependencies: basic_deps, install: true,
)
