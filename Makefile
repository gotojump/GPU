

all:
	nvcc Wireframe.cu -o Wireframe -lm -lX11

exec:
	./Wirefarme

export:
	PATH=/usr/local/cuda/bin:$PATH
	export PATH=/usr/bin:$PATH

test_seq:
	rm -rf SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 16  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 64  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 180 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 360 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 720 -s >> SaidaSeq.txt

	./Wireframe -t 5 -f Objects/Teapot.obj -r 16  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 64  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 180 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 360 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 720 -s >> SaidaSeq.txt

	./Wireframe -t 5 -f Objects/Skeleton.obj -r 16  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 64  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 180 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 360 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 720 -s >> SaidaSeq.txt

	./Wireframe -t 5 -f Objects/Bunny.obj -r 16  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 64  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 180 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 360 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 720 -s >> SaidaSeq.txt

	./Wireframe -t 5 -f Objects/Rose.obj -r 16  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 64  -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 180 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 360 -s >> SaidaSeq.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 720 -s >> SaidaSeq.txt

test_gpu:
	rm -rf SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 16     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 64     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 180    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 360    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Cube.obj -r 720    >> SaidaGPU.txt

	./Wireframe -t 5 -f Objects/Teapot.obj -r 16     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 64     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 180    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 360    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Teapot.obj -r 720    >> SaidaGPU.txt

	./Wireframe -t 5 -f Objects/Skeleton.obj -r 16     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 64     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 180    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 360    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Skeleton.obj -r 720    >> SaidaGPU.txt

	./Wireframe -t 5 -f Objects/Bunny.obj -r 16     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 64     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 180    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 360    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Bunny.obj -r 720    >> SaidaGPU.txt

	./Wireframe -t 5 -f Objects/Rose.obj -r 16     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 64     >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 180    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 360    >> SaidaGPU.txt
	./Wireframe -t 5 -f Objects/Rose.obj -r 720    >> SaidaGPU.txt

