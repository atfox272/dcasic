.PHONY: all pre_sim input_gen sim output_anal clean

all: clean pre_sim input_gen sim output_anal

pre_sim:
	if not exist dut_env\dut_output\img_txt.txt (type nul > dut_env\dut_output\img_txt.txt)

input_gen:
	python dut_env/dut_input/img2txt.py

sim:
	$(MAKE) -f tool_run

output_anal:
	python dut_env/dut_output/txt2img.py

clean:
	if exist dut_env\dut_input\img_txt.txt del /f dut_env\dut_input\img_txt.txt
	if exist dut_env\dut_output\img_txt.txt del /f dut_env\dut_output\img_txt.txt
	if exist output.jpg del /f output.jpg
	$(MAKE) -f tool_run clean