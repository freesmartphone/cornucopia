include $(top_srcdir)/Makefile.decl

NULL =

AM_CFLAGS = \
	-I$(top_srcdir) \
	$(GLIB_CFLAGS) \
	$(ALSA_CFLAGS) \
	$(NULL)

INCLUDES = \
	-I../fsoframework

noinst_PROGRAMS = $(TEST_PROGS)

VALAC_ARGS = \
	-C \
	--basedir $(top_srcdir) \
	--vapidir ../vapi/ \
	--pkg linux \
	--pkg alsa \
	--pkg glib-2.0 \
	--pkg gio-2.0

#
# alsa mixer test
#
TEST_PROGS += testalsamixer
testalsamixer_VALASOURCES = testalsamixer.vala
testalsamixer_SOURCES = testalsamixer.c
$(testalsamixer_SOURCES): $(testalsamixer_VALASOURCES)
	$(VALAC) $(VALAC_ARGS) $^
	touch $@
testalsamixer_LDADD = $(GLIB_LIBS) $(ALSA_LIBS)
EXTRA_DIST += $(testalsamixer_VALASOURCES)

#
# alsa pcm test
#
TEST_PROGS += testalsapcm
testalsapcm_VALASOURCES = testalsapcm.vala
testalsapcm_SOURCES = testalsapcm.c
$(testalsapcm_SOURCES): $(testalsapcm_VALASOURCES)
	$(VALAC) $(VALAC_ARGS) $^
	touch $@
testalsapcm_LDADD = $(GLIB_LIBS) $(ALSA_LIBS)
EXTRA_DIST += $(testalsapcm_VALASOURCES)

#
# linux.vapi tests
#
TEST_PROGS += testlinux
testlinux_VALASOURCES = testlinux.vala
testlinux_SOURCES = testlinux.c
$(testlinux_SOURCES): $(testlinux_VALASOURCES)
	$(VALAC) $(VALAC_ARGS) $^
	touch $@
testlinux_LDADD = $(GLIB_LIBS) $(ALSA_LIBS)
EXTRA_DIST += $(testlinux_VALASOURCES)

CLEANFILES = \
    $(TEST_PROGS) \
    *.? \
    $(NULL)

MAINTAINERCLEANFILES = \
  Makefile.in \
  *.la \
  *.lo \
  $(NULL)
