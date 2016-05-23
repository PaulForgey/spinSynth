SPIN=/usr/local/bin/openspin
PYTHON=/usr/bin/python
TARGET=synth

DEPS=\
	SPI\ Memory\ Driver.spin \
	synth.osc.spin \
	synth.ui.spin \
	synth.env.spin \
	synth.out.spin \
	synth.vga.spin \
	synth.flash.spin \
	synth.spin \
	synth.voice.spin \
	synth.midi.spin \
	synth.ui.graphics.spin \
	synth.osc.tables.spin

all: $(TARGET).binary

$(TARGET).binary:: $(DEPS)
	$(SPIN) $(TARGET).spin

clean:
	rm -f $(TARGET).binary
	rm -f synth.osc.tables.spin

synth.osc.tables.spin: tables.py
	$(PYTHON) tables.py > $@

