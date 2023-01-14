version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala'
)

basic_sources = [
  'main.vala',
  'historyconverter.vala',
  'historyparsers.vala',
  version_file
]

basic_deps = [
  glib,
  gobject,
  gio
]

executable('shell-history-convert', basic_sources,
  dependencies: basic_deps, install: true,
)
