#include "cuda_runtime.h"
#include "curand_kernel.h"
#include "device_launch_parameters.h"
#include "config.h"
#include <stdlib.h>
#include <stdio.h>
#include <float.h>

// ���CUDA������Ϣ
void CheckCudaError(cudaError_t err, char *errMsg);
#define CUDA_CHECK_RETURN(value1, value2) CheckCudaError(value1, value2)

// ͳ��GPU����ʱ��
void calcGPUTimeStart(char *message);
void calcGPUTimeEnd();

// ----device kernel----

// k-combination���ֵ���ӳ��Ϊ����ֵ
// nodesNum Ϊ�������
// k Ϊk-combination�����еĳ���
// combination Ϊk-combination��ֵ
// ����ӳ�������ֵ
__device__ int findIndex_kernel(int nodesNum, int k, int *combination);

// ����ֵ���ֵ���ӳ��Ϊk-combination
// nodesNum Ϊ�������
// index Ϊ���ֵ���ӳ�������ֵ
// size Ϊ���ص�k-combination�����еĳ���
// combination Ϊk-combination��ֵ
__device__ void findComb_kernel(int nodesNum, int index, int *size, int *combination);

// ����ֵ���ֵ���ӳ��Ϊk-combination
// nodesNum Ϊ�������
// index Ϊ���ֵ���ӳ�������ֵ
// size Ϊ��֪��k-combination�����еĳ���
// combination Ϊk-combination��ֵ
__device__ void findCombWithSize_kernel(int nodesNum, int index, int size, int* combi);

// ��ϱ�Ϊ����㼯��
// vi ��ǰ���
// combi ���
// size ��ϴ�С
__device__ void recoverComb_kernel(int vi, int *combi, int size);

// ����m������ѡn���������
__device__ long C_kernel(int n, int m);

// �������������
// s ��������
// n �����С
__device__ void sortArray_kernel(int *s, int n);

// �������id�͸���㼯�ϣ�����ֲ��÷�
// dev_valuesRange ���ȡֵ��Χ
// dev_samplesValues ����ȡֵ
// samplesNum ��������
// parentSet ����㼯��
// size ����㼯��Ԫ�ظ���
// curNode ��ǰ���
// nodesNum �������
__device__ double calLocalScore_kernel(int *dev_valuesRange, int *dev_samplesValues, int samplesNum, int *parentSet, int size, int curNode, int nodesNum);

// ���ֲ��Ҹ��ʱ����
// prob ���ʷֲ�
// ordersNum ������������
// r ����ֵ[0,1]
__device__ int binarySearch(double *prob, int ordersNum, double r);

// ----global kernel----

// �������н��͸���㼯�ϵľֲ��÷�
// dev_valuesRange ���ȡֵ��Χ
// dev_samplesValues ����ȡֵ
// dev_lsTable �ֲ��÷ֱ�
// samplesNum ��������
// nodesNum �������
// parentSetNum ��Ҫ����ĸ���㼯�ϵĸ���
__global__ void calcAllPossibleLocalScore_kernel(int *dev_valuesRange, int *dev_samplesValues, double *dev_lsTable, int samplesNum, int nodesNum, int parentSetNum);

// �������N����������
// dev_newOrders ���ɵ���������
// dev_curandState GPU�д洢curand�����״̬
// nodesNum �������
__global__ void generateOrders_kernel(int *dev_newOrders, curandState *dev_curandState, int nodesNum);

// ����������������ĵ÷�
// dev_maxLocalScore ÿ����㸸��㼯�ϵ���ߵ÷�
// dev_ordersScore ��������ĵ÷�
// nodesNum �������
__global__ void calcAllOrdersScore_kernel(double *dev_maxLocalScore, double *dev_ordersScore, int nodesNum);

// ��ʼ��curand��״̬
// dev_curandState GPU�д洢curand�����״̬
// seed curand�������
__global__ void curandSetup_kernel(curandState *dev_curandState, unsigned long long seed);

// ��I���в���
// dev_prob I�ķֲ�
// dev_samples ����
// dev_curandState GPU�д洢curand�����״̬
// ordersNum �������������
__global__ void sample_kernel(double *dev_prob, int *dev_samples, curandState *dev_curandState, int ordersNum);

// ����ÿһ�Խ��͸���㼯�ϵľֲ��÷�
// dev_lsTable �ֲ��÷ֱ�
// dev_newOrders ���ɵ���������
// dev_parentSetScore �������������ÿһ�Խ��͸���㼯�ϵĵ÷�
// nodesNum �������
// parentSetNum ���п��ܵĸ���㼯�ϵĸ���
// parentSetNumInOrder һ�����������п��ܵĸ���㼯�ϵĸ���
__global__ void calcOnePairPerThread_kernel(double * dev_lsTable, int * dev_newOrders, double * dev_parentSetScore, int nodesNum, int parentSetNum, int parentSetNumInOrder);

// ����ÿ����㸸��㼯�ϵ���ߵ÷�
// dev_parentSetScore �������������ÿһ�Խ��͸���㼯�ϵĵ÷�
// dev_maxLocalScore ÿ����㸸��㼯�ϵ���ߵ÷�
// parentSetNumInOrder һ�����������п��ܵĸ���㼯�ϵĸ���
// nodesNum �������
__global__ void calcMaxParentSetScoreForEachNode_kernel(double *dev_parentSetScore, double *dev_maxLocalScore, int parentSetNumInOrder, int nodesNum);