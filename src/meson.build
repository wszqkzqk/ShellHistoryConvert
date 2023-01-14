conf_data = configuration_data()
conf_data.set('version', meson.project_version())

configure_file(
  input : 'version.vala.in',
  output : 'version.vala',
  configuration : conf_data
)

basic_sources = [
  'main.vala',
  'historyconverter.vala',
  'historyparsers.vala',
  meson.current_build_dir()/'version.vala'
]

basic_deps = [
  glib,
  gobject,
  gio
]

executable('shell-history-convert', basic_sources,
  dependencies: basic_deps, install: true,
)
