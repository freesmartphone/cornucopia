include $(top_srcdir)/Makefile.decl
NULL =

AM_CFLAGS = \
	-include $(CONFIG_HEADER) \
	-DG_LOG_DOMAIN=\"fsodata.world\" \
	$(NULL)
AM_VALAFLAGS =


modlibexecdir = $(libdir)/cornucopia/modules/fsodata
modlibexec_LTLIBRARIES = world.la
world_la_SOURCES = plugin.vala
world_la_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir $(top_srcdir)/src/lib \
	--pkg glib-2.0 \
	--pkg gee-0.8 \
	--pkg fso-glib-1.0 \
	--pkg fsoframework-2.0 \
	--pkg fsodata-2.0 \
	$(DEBUG_VALAFLAGS) \
	$(NULL)
world_la_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	$(FSO_GLIB_CFLAGS) \
	$(FSO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(DEBUG_CFLAGS) \
	$(NULL)
world_la_LIBADD = \
	$(FSO_GLIB_LIBS) \
	$(FSO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/src/lib/libfsodata.la \
	$(NULL)
world_la_LDFLAGS = -no-undefined -module -avoid-version
# world_la_LIBTOOLFLAGS = --tag=disable-static
