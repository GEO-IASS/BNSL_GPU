#include "cuda_kernel.cuh"
#include "cpu_function.h"

// ��ʼ��
void BNSL_init();

// �������оֲ��÷�
void BNSL_calLocalScore();

// �㷨ִ��
void BNSL_start();

// ����㷨���
void BNSL_printResult();

// �㷨����
void BNSL_finish();