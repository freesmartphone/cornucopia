m4_define([misc-vapi_released], [0])
m4_define([misc-vapi_base_version], [0.5.1])
m4_define([misc-vapi_maybe_gitrev], m4_if(misc-vapi_released, [1], [], [m4_esyscmd([git show-ref --hash=5 HEAD | tr -d '\n\r'])]))
m4_define([misc-vapi_version], m4_if(misc-vapi_released, [1], [misc-vapi_base_version], [misc-vapi_base_version-misc-vapi_maybe_gitrev]))

AC_INIT([misc-vapi], misc-vapi_version, [fso@openphoenux.org], [misc-vapi])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AM_INIT_AUTOMAKE([dist-bzip2])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

PKG_PROG_PKG_CONFIG([0.21])

#########################################################################################
# Vala building options -- allows tarball builds without installing vala
#########################################################################################

VALA_REQUIRED=0.16.0

AC_ARG_ENABLE([vala], AS_HELP_STRING([--enable-vala],[Enable building from Vala sources]),
              [enable_vala=$enableval], [enable_vala=no])

# Force Vala for non-release builds
m4_if(fsogsmd_released, [1], [],
      [
        enable_vala=yes
        echo "Vala compiler required for non-release builds; requiring Vala..."
      ])

if test "x$enable_vala" = "xyes" ; then
    AM_PROG_VALAC([$VALA_REQUIRED])
    if test "x$VALAC" = "x" ; then
        AC_MSG_ERROR([Vala requested but valac is not installed])
    fi
fi

AM_CONDITIONAL([HAVE_VALA], [test "x$enable_vala" = "xyes"])

#########################################################################################
# check for debugging
#########################################################################################

AC_ARG_ENABLE(debug,
  [  --enable-debug            Enable debug build (default=disabled)],
  [enable_debug=$enableval],
  [enable_debug="no"])
AM_CONDITIONAL( [WANT_DEBUG], [test x"$enable_debug" = x"yes"])

#########################################################################################
# Check for various dependencies
#########################################################################################

VALA_REQUIRED=0.16.0
GLIB_REQUIRED=2.18.0
ALSA_REQUIRED=0.20
# glib and friends
PKG_CHECK_MODULES(GLIB,
  glib-2.0 >= $GLIB_REQUIRED
  gobject-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)

#########################################################################################
# optional feature: tests [default=yes]
#########################################################################################
AC_ARG_ENABLE(tests,      [  --disable-tests      skip building the tests [[default=no]]])
AM_CONDITIONAL(MAKE_TESTS, test x$enable_tests != xno)
AC_MSG_CHECKING([whether to compile the tests])
if test "$enable_tests" != no; then
  AC_MSG_RESULT(yes)
  # glib and friends
  PKG_CHECK_MODULES(ALSA,
    alsa >= $ALSA_REQUIRED)
  AC_SUBST(ALSA_CFLAGS)
  AC_SUBST(ALSA_LIBS)
else
  AC_MSG_RESULT(no)
fi

#########################################################################################
# output
#########################################################################################
AC_CONFIG_FILES([Makefile
  tests/Makefile
  vapi/Makefile
  misc-vapi-1.0.pc])

AC_OUTPUT
