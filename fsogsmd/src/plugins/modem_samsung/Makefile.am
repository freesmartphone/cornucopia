include $(top_srcdir)/Makefile.decl

NULL =

AM_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	-I$(top_srcdir)/src/3rdparty \
	$(PALM_CFLAGS) \
	$(FSO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(SAMSUNG_CFLAGS) \
	-DG_LOG_DOMAIN=\"fsogsm.modem_samsung\" \
	$(NULL)

noinst_PROGRAMS = $(TEST_PROGS)

progs_ldadd = \
	$(PALM_LIBS) \
	$(FSO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(SAMSUNG_LIBS) \
	$(top_srcdir)/src/lib/libfsogsm.la

VALAC_ARGS = \
	--basedir $(top_srcdir) \
	--vapidir ../../lib \
	--pkg posix \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg fso-glib-1.0 \
	--pkg fsoframework-2.0 \
	--pkg fsotransport-2.0 \
	--pkg fsogsm-2.0 \
	--pkg samsung-ipc-1.0 \
	$(NULL)

if WANT_DEBUG
VALAC_ARGS += -g -D DEBUG
AM_CFLAGS += -ggdb -O0
endif

#
# plugin
#
modlibexecdir = $(libdir)/cornucopia/modules/fsogsm
modlibexec_LTLIBRARIES = modem_samsung.la

modem_samsung_la_VALASOURCES = \
 plugin.vala \
 channel.vala \
 unsolicited.vala \
 $(NULL)

modem_samsung_la_SOURCES = $(modem_samsung_la_VALASOURCES:.vala=.c)

$(modem_samsung_la_SOURCES): $(modem_samsung_la_VALASOURCES)
	$(VALAC) -C $(VALAC_ARGS) $^
	touch $@
modem_samsung_la_LIBADD = $(progs_ldadd)
modem_samsung_la_LDFLAGS = -no-undefined -module -avoid-version
modem_samsung_la_LIBTOOLFLAGS = --tag=disable-static

CLEANFILES = \
    *.c \
    *.h \
    *.la \
    *.lo \
    $(NULL)

MAINTAINERCLEANFILES = \
  Makefile.in \
  $(NULL)