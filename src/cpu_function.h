#include "config.h"
#include "mpf.h"
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <float.h>

// ��ȡ����������ȡֵ��Χ
void readNodeInfo(int *nodesNum, int **valuesRange);

// ��ȡ���۲�����
void readSamples(int **samplesValues, int *samplesNum, int nodesNum);

// ����m������ѡn���������
long C(int n, int m);

// �����ʼ��һ����������
void randInitOrder(int *s, int nodesNum);

// ����CDF�ۻ����ʷֲ�
// ordersScore ��������ĵ÷�
// prob CDF�ۻ����ʷֲ�
// ordersNum ��������ĸ���
int calcCDF(double *ordersScore, double *prob);

void calcCDFInit(int ordersNum);

void calcCDFFinish();

// ͳ��CPU����ʱ��
void calcCPUTimeStart(char *message);
void calcCPUTimeEnd();