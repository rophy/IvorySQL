# Copyright (c) 2022-2024, PostgreSQL Global Development Group
# Portions Copyright (c) 2023-2025, IvorySQL Global Development Team

ivorysql_ora_sources = files(
  'src/ivorysql_ora.c',
  'src/guc/guc.c',
  'src/datatype/oracharchar.c',
  'src/datatype/oracharbyte.c',
  'src/datatype/oravarcharchar.c',
  'src/datatype/oravarcharbyte.c',
  'src/datatype/oradate.c',
  'src/datatype/oratimestamp.c',
  'src/datatype/oratimestamptz.c',
  'src/datatype/oratimestampltz.c',
  'src/datatype/yminterval.c',
  'src/datatype/dsinterval.c',
  'src/datatype/compatible_oracle_precedence.c',
  'src/datatype/common_datatypes.c',
  'src/datatype/raw_long.c',
  'src/datatype/binary_float.c',
  'src/datatype/binary_double.c',
  'src/builtin_functions/character_datatype_functions.c',
  'src/builtin_functions/datetime_datatype_functions.c',
  'src/builtin_functions/numeric_datatype_functions.c',
  'src/builtin_functions/misc_functions.c',
  'src/merge/ora_merge.c',
  'src/sysview/sysview_functions.c',
  'src/xml_functions/ora_xml_functions.c',
  'src/builtin_packages/dbms_utility/dbms_utility.c',
)

if host_system == 'windows'
  ivorysql_ora_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'ivorysql_ora',
    '--FILEDESC', 'ivorysql_ora - Oracle Compatible extenison on Postgres Database',])
endif

custom_target('ivorysql_ora--1.0.sql',
  output: 'ivorysql_ora--1.0.sql',
  command: [perl, '../contrib/ivorysql_ora/gensql.pl', 'meson', '1.0'],
  capture: true,
  install: true,
  install_dir: contrib_data_args['install_dir'],
)

ivorysql_ora = shared_module('ivorysql_ora',
  ivorysql_ora_sources,
  include_directories: plisql_inc,
  kwargs: contrib_mod_args,
)
contrib_targets += ivorysql_ora

install_data(
  'ivorysql_ora.control',
  kwargs: contrib_data_args,
)

install_data(
  'preload_ora_misc.sql',
  install_dir: dir_data,
)

tests += {
  'name': 'ivorysql_ora',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'regress': {
    'sql': [
      'ora_character',
      'ora_datetime',
      'ora_interval',
      'ora_number',
      'ora_binary_float',
      'ora_binary_double',
      'ora_raw_long',
      'ora_character_datatype_functions',
      'ora_datetime_datatype_functions',
      'ora_misc_functions',
      'ora_merge',
      'datatype_and_func_bugs',
      'ora_sysview',
      'ora_like_operator',
      'ora_xml_functions',
      'dbms_utility',
    ],
    'tap': {
      'tests': [
        't/001_verify_heapam.pl',
        't/002_cic.pl',
        't/003_cic_2pc.pl',
      ]
    },
  },
}
