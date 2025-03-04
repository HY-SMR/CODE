%%%%%%%%%咸鱼号：默默科研仔
%%  清空环境变量
warning off             % 关闭报警信息
close all               % 关闭开启的图窗
clear                   % 清空变量
clc                     % 清空命令行

%%  导入数据（时间序列的单列数据）
result = xlsread('FC35000.xlsx');

%%  数据分析
num_samples = length(result);  % 样本个数 
kim = 2;                      % 延时步长（kim个历史数据作为自变量）
zim =  1;                      % 跨zim个时间点进行预测

%%  划分数据集
for i = 1: num_samples - kim - zim + 1
    res(i, :) = [reshape(result(i: i + kim - 1), 1, kim), result(i + kim + zim - 1)];
end
%%  数据集分析
outdim = 1;                                  % 最后一列为输出
num_size = 0.55;                              % 训练集占数据集比例
num_train_s = round(num_size * num_samples); % 训练集样本个数
f_ = size(res, 2) - outdim;                  % 输入特征维度

%%  划分训练集和测试集
P_train = res(1: num_train_s, 1: f_)';
T_train = res(1: num_train_s, f_ + 1: end)';
M = size(P_train, 2);

P_test = res(num_train_s + 1: end, 1: f_)';
T_test = res(num_train_s + 1: end, f_ + 1: end)';
N = size(P_test, 2);

%%  数据归一化
[P_train, ps_input] = mapminmax(P_train, 0, 1);
P_test = mapminmax('apply', P_test, ps_input);

[t_train, ps_output] = mapminmax(T_train, 0, 1);
t_test = mapminmax('apply', T_test, ps_output);

%%  数据平铺
% 将数据平铺成1维数据只是一种处理方式
% 也可以平铺成2维数据，以及3维数据，需要修改对应模型结构
% 但是应该始终和输入层数据结构保持一致
P_train =  double(reshape(P_train, f_, 1, 1, M));
P_test  =  double(reshape(P_test , f_, 1, 1, N));

% t_train = t_train';
% t_test  = t_test' ;
t_train =  double(t_train)';
t_test  =  double(t_test )';
%%  构造网络结构
layers = [
 imageInputLayer([f_, 1, 1])                 % 输入层 输入数据规模[15, 1, 1]
 
 convolution2dLayer([3, 1], 16, 'Stride', [1, 1], 'Padding', 'same')              
                                             % 卷积核大小 3 * 1 生成 16 张特征图
 batchNormalizationLayer                     % 批归一化层
 reluLayer                                   % Relu激活层
 
 convolution2dLayer([3, 1], 32, 'Stride', [1, 1], 'Padding', 'same') 
                                             % 卷积核大小 3 * 1 生成 32 张特征图
 batchNormalizationLayer                     % 批归一化层
 reluLayer                                   % Relu激活层

 dropoutLayer(0.2)                                  % Dropout层
 fullyConnectedLayer(outdim)                      % 全连接层
 regressionLayer];                           % 回归层

%%  参数设置
options = trainingOptions('adam', ...      % Adam 梯度下降算法
    'MaxEpochs', 50, ...                  % 最大训练次数 800
    'InitialLearnRate', 5e-3, ...          % 初始学习率为 0.005
    'LearnRateSchedule', 'piecewise', ...  % 学习率下降
    'LearnRateDropFactor', 0.1, ...        % 学习率下降因子 0.1
    'LearnRateDropPeriod', 600, ...        % 经过 600 次训练后 学习率为 0.005 * 0.1
    'L2Regularization', 1e-4, ...          % 正则化参数
    'Shuffle', 'every-epoch', ...          % 每次训练打乱数据集
    'Plots', 'training-progress', ...      % 画出曲线
    'Verbose', false);
%%  训练模型
net = trainNetwork(P_train, t_train, layers, options);

%%  仿真预测
t_sim1 = predict(net, P_train);
t_sim2 = predict(net, P_test );

%%  数据反归一化
T_sim1 = mapminmax('reverse', t_sim1, ps_output);
T_sim2 = mapminmax('reverse', t_sim2, ps_output);

%%  均方根误差
error1 = sqrt(sum((T_sim1' - T_train).^2) ./ M);
error2 = sqrt(sum((T_sim2' - T_test ).^2) ./ N);

%%  查看网络结构
analyzeNetwork(net)

%%  绘图
figure
plot(1: M, T_train, 'r-', 1: M, T_sim1, 'b-', 'LineWidth', 1)
legend('真实值', '预测值')
xlabel('预测样本')
ylabel('预测结果')
string = {'训练集预测结果对比'; ['RMSE=' num2str(error1)]};
title(string)
xlim([1, M])
grid

figure
plot(1: N, T_test, 'r-', 1: N, T_sim2, 'b-', 'LineWidth', 1)
legend('真实值', '预测值')
xlabel('预测样本')
ylabel('预测结果')
string = {'测试集预测结果对比'; ['RMSE=' num2str(error2)]};
title(string)
xlim([1, N])
grid

%%  相关指标计算
% R2
R1 = 1 - norm(T_train - T_sim1')^2 / norm(T_train - mean(T_train))^2;
R2 = 1 - norm(T_test  - T_sim2')^2 / norm(T_test  - mean(T_test ))^2;

disp(['训练集数据的R2为：', num2str(R1)])
disp(['测试集数据的R2为：', num2str(R2)])

% MAE
mae1 = sum(abs(T_sim1' - T_train)) ./ M ;
mae2 = sum(abs(T_sim2' - T_test )) ./ N ;

disp(['训练集数据的MAE为：', num2str(mae1)])
disp(['测试集数据的MAE为：', num2str(mae2)])

% MBE
mbe1 = sum(T_sim1' - T_train) ./ M ;
mbe2 = sum(T_sim2' - T_test ) ./ N ;

disp(['训练集数据的MBE为：', num2str(mbe1)])
disp(['测试集数据的MBE为：', num2str(mbe2)])

%  MAPE
mape1 = sum(abs((T_sim1' - T_train)./T_train)) ./ M ;
mape2 = sum(abs((T_sim2' - T_test )./T_test )) ./ N ;

disp(['训练集数据的MAPE为：', num2str(mape1)])
disp(['测试集数据的MAPE为：', num2str(mape2)])

%%  绘制散点图
sz = 25;
c = 'b';

figure
scatter(T_train, T_sim1, sz, c)
hold on
plot(xlim, ylim, '--k')
xlabel('训练集真实值');
ylabel('训练集预测值');
xlim([min(T_train) max(T_train)])
ylim([min(T_sim1) max(T_sim1)])
title('训练集预测值 vs. 训练集真实值')

figure
scatter(T_test, T_sim2, sz, c)
hold on
plot(xlim, ylim, '--k')
xlabel('测试集真实值');
ylabel('测试集预测值');
xlim([min(T_test) max(T_test)])
ylim([min(T_sim2) max(T_sim2)])
title('测试集预测值 vs. 测试集真实值')
%%%%%%%%%咸鱼号：默默科研仔