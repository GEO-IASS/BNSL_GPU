#include "BNSL_GPU.cuh"

// �ڵ�ȡֵ��Χ
int * valuesRange;

// ������
int nodesNum = 0;

// ����ȡֵ
int * samplesValues;

// ��������
int samplesNum;

// ����㼯�ϵĸ���
int parentSetNum;

// �ֲ��÷�Hash��
double * dev_lsTable;

// ������
int* globalBestGraph;
int* globalBestOrder;
double globalBestScore;

void BNSL_init(){

	// ��ȡ�ڵ���Ϣ
	readNodeInfo(&nodesNum, &valuesRange);

	// ��ȡ��������
	readSamples(&samplesValues, &samplesNum, nodesNum);

	// ��ʼ��GPU
	CUDA_CHECK_RETURN(cudaDeviceReset(), "cudaDeviceReset failed.");
}

void BNSL_calLocalScore(){

	int i;
	parentSetNum = 0;
	for (i = 0; i <= CONSTRAINTS; i++) {
		parentSetNum = parentSetNum + C(i, nodesNum - 1);
	}

	int * dev_valuesRange;
	int * dev_samplesValues;

	// ��GPU�з����ڴ�ռ�
	CUDA_CHECK_RETURN(cudaMalloc(&dev_lsTable, nodesNum * parentSetNum * sizeof(double)), "cudaMalloc failed: dev_lsTable.");
	CUDA_CHECK_RETURN(cudaMalloc(&dev_valuesRange, nodesNum * sizeof(int)), "cudaMalloc failed: dev_valuesRange.");
	CUDA_CHECK_RETURN(cudaMalloc(&dev_samplesValues, samplesNum * nodesNum * sizeof(int)), "cudaMalloc failed: dev_samplesValues.");

	// �����ݿ�����GPU�ڴ���
	CUDA_CHECK_RETURN(cudaMemcpy(dev_valuesRange, valuesRange, nodesNum * sizeof(int), cudaMemcpyHostToDevice), "cudaMemcpy failed: valuesRange -> dev_valuesRange");
	CUDA_CHECK_RETURN(cudaMemcpy(dev_samplesValues, samplesValues, samplesNum * nodesNum * sizeof(int), cudaMemcpyHostToDevice), "cudaMemcpy failed: samplesValues -> dev_samplesValues");

	// ����GPU����
	int threadNum = 64;
	int total = parentSetNum * nodesNum;
	int blockNum = (total - 1) / threadNum + 1;
	calcAllPossibleLocalScore_kernel << <blockNum, threadNum >> >(dev_valuesRange, dev_samplesValues, dev_lsTable, samplesNum, nodesNum, parentSetNum);
	CUDA_CHECK_RETURN(cudaGetLastError(), "calcAllPossibleLocalScore_kernel launch failed.");
	CUDA_CHECK_RETURN(cudaDeviceSynchronize(), "calcAllPossibleLocalScore_kernel failed on running.");

	// �ͷ���GPU�з�����ڴ�ռ�
	CUDA_CHECK_RETURN(cudaFree(dev_valuesRange), "cudaFree failed: dev_valuesRange.");
	CUDA_CHECK_RETURN(cudaFree(dev_samplesValues), "cudaFree failed: dev_samplesValues.");

	// ���մ���������ݵ��ڴ�
	free(valuesRange);
	free(samplesValues);
}

void BNSL_start(){

	int i, j, iter;
	int parentSetNumInOrder = 0;
	for (i = 0; i < nodesNum; i++){
		for (j = 0; j <= CONSTRAINTS&&j < i + 1; j++){
			parentSetNumInOrder += C(j, i);
		}
	}

	// ÿ���²���63��order������1������order
	int ordersNum = 128;

	// ��������
	int iterNum = 0;

	// ��ʼ������������������
	srand((unsigned int)time(NULL));

	// �������
	int seed = 1234;

	// GPU�д洢�²�������������
	int * dev_newOrders;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_newOrders, ordersNum * nodesNum * sizeof(int)), "cudaMalloc failed: dev_newOrders.");
	// CPU�д洢��������
	int * newOrder = (int *)malloc(nodesNum * sizeof(int));
	// ��ʼ����������
	randInitOrder(newOrder, nodesNum);

	// GPU�д洢������������ĸ��ڵ㼯�ϵĵ÷�
	double * dev_parentSetScore;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_parentSetScore, ordersNum * parentSetNumInOrder * sizeof(double)), "cudaMalloc failed: dev_result.");

	// GPU�д洢ÿ����㸸��㼯�ϵ���ߵ÷�
	double * dev_maxLocalScore;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_maxLocalScore, ordersNum * nodesNum * sizeof(double)), "cudaMalloc failed: dev_maxLocalScore.");

	// GPU�д洢ÿ����������ĵ÷�
	double * dev_ordersScore;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_ordersScore, ordersNum * sizeof(double)), "cudaMalloc failed: dev_ordersScore.");
	// CPU�д洢ÿ����������ĵ÷�
	double * ordersScore = (double *)malloc(ordersNum * sizeof(double));

	// GPU�д洢I�ĸ��ʷֲ�
	double *dev_prob;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_prob, ordersNum * sizeof(double)), "cudaMalloc failed: dev_prob.");
	// CPU��I�ĸ��ʷֲ�
	double *prob = (double *)malloc(ordersNum * sizeof(double));

	// GPU�д洢I������
	int *dev_samples;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_samples, ordersNum * sizeof(int)), "cudaMalloc failed: dev_samples.");
	// CPU��I������
	int *samples = (int *)malloc(ordersNum * sizeof(int));

	// CPU�д洢ȫ�����ŵ���������
	globalBestOrder = (int *)malloc(nodesNum * sizeof(int));
	globalBestScore = -FLT_MAX;

	// GPU�д洢curand�����״̬
	curandState *dev_curandState;
	CUDA_CHECK_RETURN(cudaMalloc(&dev_curandState, ordersNum * sizeof(curandState)), "cudaMalloc failed: dev_curandState.");
	// ��ʼ��curand�����״̬
	curandSetup_kernel << < 1, ordersNum >> >(dev_curandState, seed);
	CUDA_CHECK_RETURN(cudaGetLastError(), "curandSetup_kernel launch failed.");

	calcCDFInit(ordersNum);

	for (iter = 0; iter < iterNum; iter++){
		// ��������µ���������
		CUDA_CHECK_RETURN(cudaMemcpy(dev_newOrders, newOrder, nodesNum * sizeof(int), cudaMemcpyHostToDevice), "cudaMemcpy failed: newOrder -> dev_newOrders.");
		generateOrders_kernel << <1, ordersNum, nodesNum * 4 >> >(dev_newOrders, dev_curandState, nodesNum);
		CUDA_CHECK_RETURN(cudaGetLastError(), "generateOrders_kernel launch failed.");

		//calcGPUTimeStart("calcOnePairPerThread_kernel: ");
		int totalPairNum = ordersNum * parentSetNumInOrder;
		int threadDimX = 128;
		int blockDim = (totalPairNum - 1) / threadDimX + 1;
		int blockDimX = 1;
		int blockDimY = 1;
		if (blockDim < 65535){
			blockDimX = 1;
			blockDimY = blockDim;
		}
		else{
			blockDimX = (blockDim - 1) / 65535 + 1;
			blockDimY = 65535;
		}
		dim3 gridDim(blockDimX, blockDimY);
		calcOnePairPerThread_kernel << <gridDim, threadDimX >> >(dev_lsTable, dev_newOrders, dev_parentSetScore, nodesNum, parentSetNum, parentSetNumInOrder);
		CUDA_CHECK_RETURN(cudaGetLastError(), "calcOnePairPerThread_kernel launch failed.");
		//calcGPUTimeEnd();

		// ����ÿ�����÷���ߵĸ���㼯��
		calcMaxParentSetScoreForEachNode_kernel << <nodesNum, ordersNum >> >(dev_parentSetScore, dev_maxLocalScore, parentSetNumInOrder, nodesNum);
		CUDA_CHECK_RETURN(cudaGetLastError(), "calcMaxLocalScoreForEachNode_kernel launch failed.");

		// ����������������ĵ÷�
		calcAllOrdersScore_kernel << <1, ordersNum >> >(dev_maxLocalScore, dev_ordersScore, nodesNum);
		CUDA_CHECK_RETURN(cudaGetLastError(), "calcAllOrdersScore_kernel launch failed.");
		CUDA_CHECK_RETURN(cudaMemcpy(ordersScore, dev_ordersScore, ordersNum * sizeof(double), cudaMemcpyDeviceToHost), "cudaMemcpy failed: dev_ordersScore -> ordersScore.");

		int *newOrders = (int *)malloc(ordersNum * nodesNum * sizeof(int));
		CUDA_CHECK_RETURN(cudaMemcpy(newOrders, dev_newOrders, ordersNum * nodesNum * sizeof(int), cudaMemcpyDeviceToHost), "test");

		// ����������ĵ÷�ת��ΪI���ۻ����ʷֲ�
		int maxId = calcCDF(ordersScore, prob);

		// �����Ž�Ƚ�
		if (ordersScore[maxId] > globalBestScore){
			CUDA_CHECK_RETURN(cudaMemcpy(globalBestOrder, dev_newOrders + maxId * nodesNum, nodesNum * sizeof(int), cudaMemcpyDeviceToHost), "cudaMemcpy failed: dev_newOrders -> globalBestOrder");
			globalBestScore = ordersScore[maxId];
		}

		// �Ը�������Iȡ��
		CUDA_CHECK_RETURN(cudaMemcpy(dev_prob, prob, ordersNum * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy failed: prob -> dev_prob.");
		sample_kernel << <1, ordersNum, ordersNum * 8 >> >(dev_prob, dev_samples, dev_curandState, ordersNum);
		CUDA_CHECK_RETURN(cudaGetLastError(), "sample_kernel launch failed.");
		CUDA_CHECK_RETURN(cudaMemcpy(samples, dev_samples, ordersNum * sizeof(int), cudaMemcpyDeviceToHost), "cudaMemcpy failed: dev_samples -> samples.");

		int r = rand() % ordersNum;
		CUDA_CHECK_RETURN(cudaMemcpy(newOrder, dev_newOrders + samples[r] * nodesNum, nodesNum * sizeof(int), cudaMemcpyDeviceToHost), "cudaMemcpy failed: dev_newOrders -> newOrder");
	}

	CUDA_CHECK_RETURN(cudaFree(dev_newOrders), "cudaFree failed: dev_newOrders.");
	CUDA_CHECK_RETURN(cudaFree(dev_parentSetScore), "cudaFree failed: dev_parentSetScore.");
	CUDA_CHECK_RETURN(cudaFree(dev_maxLocalScore), "cudaFree failed: dev_maxLocalScore.");
	CUDA_CHECK_RETURN(cudaFree(dev_ordersScore), "cudaFree failed: dev_ordersScore.");
	CUDA_CHECK_RETURN(cudaFree(dev_prob), "cudaFree failed: dev_prob.");
	CUDA_CHECK_RETURN(cudaFree(dev_samples), "cudaFree failed: dev_samples.");
	CUDA_CHECK_RETURN(cudaFree(dev_curandState), "cudaFree failed: dev_curandState.");
	free(newOrder);
	free(ordersScore);
	free(prob);
	free(samples);
	calcCDFFinish();
}

void BNSL_printResult() {
	/*
	printf("Bayesian Network learned:\n");
	for (int i = 0; i < nodesNum; i++){
		for (int j = 0; j < nodesNum; j++){
			printf("%d ", globalBestGraph[i*nodesNum + j]);
		}
		printf("\n");
	}
	*/

	printf("Best Score: %f \n", globalBestScore);
	printf("Best Topology: ");
	for (int i = 0; i < nodesNum; i++){
		printf("%d ", globalBestOrder[i]);
	}
	printf("\n");
}

void BNSL_finish(){
	CUDA_CHECK_RETURN(cudaFree(dev_lsTable), "cudaFree failed: dev_lsTable.");
	free(globalBestOrder);
	free(globalBestGraph);
}