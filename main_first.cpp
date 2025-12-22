#include <iostream>
#include <iomanip>
#include <cmath>
#include <vector>
#include <unordered_map>
#include <stdexcept>
#include <string>
#include <fstream>
#include <sstream>

using namespace std;

double rinex_str_to_double(const string& s) {
    string str = s;
    // trim
    auto start = str.find_first_not_of(" \t");
    if (start == string::npos) return 0.0;
    auto end = str.find_last_not_of(" \t");
    str = str.substr(start, end - start + 1);

    // 把所有 D/d 替换成 E
    for (char &c : str) {
        if (c == 'D' || c == 'd') c = 'E';
    }
    // 如果空，返回 0
    if (str.empty()) return 0.0;

    // 现在尝试 stod（捕获异常）
    try {
        return stod(str);
    } catch (...) {
        cerr << "转换失败: '" << str << "'" << endl;
        return 0.0;
    }
}


//卫星钟参考时
struct TOC{
    int year;
    int month;
    int day;
    int hour;
    int minute;
    double second;
    TOC(int y,int m,int d,int h,int mi,double s):year(y),month(m),day(d),hour(h),minute(mi),second(s) {}
};

//坐标点
struct Point3D
{
    double x,y,z;
    Point3D(double X,double Y,double Z):x(X),y(Y),z(Z) {}
};


//单卫星单历元星历
class Ephemery{
    public:
    string PRN;//卫星编号
    TOC toc;//历元
    double af0,af1,af2;//钟偏，钟漂，钟漂速度；
    double IODE;//星历版本
    double C_rs;
    double Delta_n;
    double M_0;
    double C_uc;
    double e;//轨道偏心率
    double C_us;
    double sqrt_A;//
    double TOE;//GPS周内秒
    double C_ic;
    double Omega;
    double C_is;
    double i_0;
    double C_rc;
    double omega;
    double Omega_dot;
    double i_dot;

    Ephemery(const string& prn, const TOC& t,double a0, double a1, double a2,
        double iode,double crs, double dn, double m0,double cuc, double ecc, double cus,
        double sqrtA, double toe,double cic, double omega0, double cis,
        double i0, double crc, double w, double omegaDot, double idot) : PRN(prn), toc(t),
            af0(a0), af1(a1), af2(a2),IODE(iode),
            C_rs(crs), Delta_n(dn), M_0(m0),
            C_uc(cuc), e(ecc), C_us(cus),sqrt_A(sqrtA), TOE(toe),
            C_ic(cic), Omega(omega0), C_is(cis),
            i_0(i0), C_rc(crc), omega(w), Omega_dot(omegaDot), i_dot(idot) {}



    // 将toc转换为GPS周内秒（从周日0时开始的秒数）
    double toc_to_gps_seconds() const {
        // 计算该日是星期几 (需要用蔡勒公式或简单近似)
        // 简化处理：假设toc的hour/minute/second直接给出了当天的时间
        // 我们需要知道该日期是周几
        int y = toc.year;
        int m = toc.month;
        int d = toc.day;
        
        // 蔡勒公式计算星期几 (0=周日, 1-6=周一到周六)
        if (m < 3) {
            m += 12;
            y -= 1;
        }
        int k = y % 100;
        int j = y / 100;
        int dow = (d + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7;
        dow = ((dow + 6) % 7);  // 转换为0=周日
        
        // 计算周内秒
        double seconds_in_day = toc.hour * 3600.0 + toc.minute * 60.0 + toc.second;
        return dow * 86400.0 + seconds_in_day;
    }

    //计算t时刻卫星位置
    Point3D calc_coordinate(double t){
        //处理跨周影响
        double tk;
        if(PRN[0]=='C'){
            tk=t-TOE-14;
        }
        else {
            tk=t-TOE;
        }
        if(tk>302400) tk=tk-604800;
        if(tk<-302400) tk=tk+604800;

        //step1 计算参考时刻平均角速度
        double GM=3.986005e14;
        double n0=sqrt(GM)/pow(sqrt_A,3);
        double n=n0+Delta_n;

        //step2 计算观测瞬间t时刻卫星的平近点角
        double M=M_0+n*tk;

        //step3 迭代计算偏近点角
        double E = M;
        for (int i = 0; i < 10; i++)
            E = M + e * sin(E); 

        //step4 计算真近点角
        double f=atan2(sqrt(1-e*e)*sin(E),cos(E)-e);

        //step5 计算升交距角（未经改正的）
        double u_uncorrected = omega+f;

        //step6 计算卫星向径（未经改正的）
        double r_uncorrected = sqrt_A*sqrt_A*(1-e*cos(E));

        //step7 计算摄动改正项
        double delta_u=C_uc*cos(2*u_uncorrected)+C_us*sin(2*u_uncorrected);
        double delta_r=C_rc*cos(2*u_uncorrected)+C_rs*sin(2*u_uncorrected);
        double delta_i=C_ic*cos(2*u_uncorrected)+C_is*sin(2*u_uncorrected);

        //step8 进行摄动改正
        double u=u_uncorrected+delta_u;
        double r=r_uncorrected+delta_r;
        double i=i_0+i_dot*(tk)+delta_i;

        //step9 计算卫星在轨道平面在坐标系下的坐标
        double x_orbit=r*cos(u);
        double y_orbit=r*sin(u);

        //step10 计算升交点经度 (区分 GPS 和 BDS)
        double omega_e = 7.2921151467e-5;
        double L;
        L = Omega + (Omega_dot - omega_e) * tk - omega_e * TOE;


        //step11 计算卫星在瞬时地心地固坐标系下的坐标
        double X=x_orbit*cos(L)-y_orbit*cos(i)*sin(L);
        double Y=x_orbit*sin(L)+y_orbit*cos(i)*cos(L);
        double Z=y_orbit*sin(i);

        return Point3D(X,Y,Z);
    }
};

//卫星
class Satellite{
    public:
    vector<Ephemery> Ephemerys;
    string PRN;
    vector<Point3D> coordinates;
    vector<double> send_times;
    vector<double> timediff_to_TOE;
    Satellite(string prn):PRN(prn){}
    Satellite() : Satellite("") {}
};


int main()
{   
    


    ifstream infile("brdm3350.19p");
    if(!infile.is_open()){
        cout<<"无法打开文件"<<endl;
        return 1;
    }


    string line;
    stringstream ss;

    //跳过表头，方法为遍历直至遇到"end of header"
    string temp;
    while(getline(infile,line)){
        if(line.find("END OF HEADER")!=string::npos){
            break;
        }
    }
    vector<Satellite> Satellites;

    while(getline(infile,line)){
        if(line[0]=='G'||line[0]=='C'){
            string prn = line.substr(0,3);
            
            // 解析时间和钟差参数
            int year = stoi(line.substr(4,4));
            int month = stoi(line.substr(9,2));
            int day = stoi(line.substr(12,2));
            int hour = stoi(line.substr(15,2));
            int minute = stoi(line.substr(18,2));
            double second = rinex_str_to_double(line.substr(21,2));
            
            // 钟差参数，注意索引修正
            double af0 = rinex_str_to_double(line.substr(23,19));
            double af1 = rinex_str_to_double(line.substr(42,19));
            double af2 = rinex_str_to_double(line.substr(61,19));
            
            TOC toc(year, month, day, hour, minute, second);
            
            vector<double> more_params;
            for(int i=0;i<7;i++){
                getline(infile,line);
                for(int j=0;j<4;j++){
                    if(line.size() >= (j+1)*19){
                        string s = line.substr(j*19+4,19);
                        more_params.push_back(rinex_str_to_double(s));
                    }
                }
            }

            Ephemery ep(prn,toc,af0,af1,af2,more_params[0],more_params[1],more_params[2],more_params[3],
            more_params[4],more_params[5],more_params[6],more_params[7],more_params[8],more_params[9],more_params[10],
            more_params[11],more_params[12],more_params[13],more_params[14],more_params[15],more_params[16]);   


            bool found = false;
            for(auto& sat : Satellites){
                if(sat.PRN == ep.PRN){
                    sat.Ephemerys.push_back(ep);
                    found = true;
                    break;
                }
            }
            
            if(!found){
                Satellite sat(ep.PRN);
                sat.Ephemerys.push_back(ep);
                Satellites.push_back(sat);
            }
        
        }   
    }
    infile.close();
    cout<<Satellites.back().Ephemerys.back().af0<<endl;

    vector<double> time_sequence;
    for(double i=0.0;i<=86400;i+=1.0){
        time_sequence.push_back(i);
    }

    //结果输出到txt文件
    ofstream outfile ("coordinates.txt");
    if(!outfile.is_open()) cout<<"无法创建或打开输出文件"<<endl;
    //表头
    outfile<<left<<setw(10)<<"PRN"<<right<<setw(20)<<"t(GNSS TIME)/s"
    <<setw(20)<<"X/m"<<setw(20)<<"Y/m"<<setw(20)<<"Z/m"<<setw(20)<<"toe/s"<<"\n";

    for(auto& sat : Satellites){
        if(sat.PRN[0] == 'G'||sat.PRN[0]=='C'){
            cout<<"正在计算卫星"<<sat.PRN<<"......"<<endl;
            // 为每个时间点选择最接近的星历
            for(double t = 0; t <= 86400; t += 300.0){  // 每5分钟计算一次
                Ephemery* best_ephem = nullptr;
                double min_time_diff = TMP_MAX;  // 使用最大值
                double min_toc_toe_diff = TMP_MAX;  // toc与toe的最小差值（用于处理toe相同的情况）
                
                // 遍历所有星历，找到时间最接近的
                // 如果多个星历的toe与t的差值相同，选择toc与toe差值最小的星历
                for(auto& ephem : sat.Ephemerys){
                    // 计算星历参考时间TOE与当前时间t的差值
                    double time_diff = fabs(ephem.TOE - t);
                    
                    // 计算toc与toe的差值（用于判断数据质量）
                    double toc_seconds = ephem.toc_to_gps_seconds();
                    double toc_toe_diff = fabs(toc_seconds - ephem.TOE);
                    // 处理跨周的情况
                    if(toc_toe_diff > 302400) toc_toe_diff = 604800 - toc_toe_diff;
                    
                    if(time_diff < min_time_diff){
                        // 找到更接近的星历
                        min_time_diff = time_diff;
                        min_toc_toe_diff = toc_toe_diff;
                        best_ephem = &ephem;
                    } else if(time_diff == min_time_diff && toc_toe_diff < min_toc_toe_diff){
                        // toe与t的差值相同，但toc与toe更接近，选择这个星历
                        min_toc_toe_diff = toc_toe_diff;
                        best_ephem = &ephem;
                    }
                }
                if(sat.PRN == "C36"&&t==41400)
                {
                    cout << "\n===========================\n";
                    cout << " C36 调试信息 t = " << t << " 秒\n";
                    cout << "===========================\n";

                    if(best_ephem)
                    {
                        cout << "使用的星历 TOE = " << best_ephem->TOE
                            << "   (与 t 的差 min_time_diff = " << min_time_diff << ")\n\n";

                        cout << "星历参数：\n";
                        cout << "  sqrt(A)     = " << best_ephem->sqrt_A << "\n";
                        cout << "  e           = " << best_ephem->e << "\n";
                        cout << "  i0          = " << best_ephem->i_0 << "\n";
                        cout << "  idot        = " << best_ephem->i_dot << "\n";
                        cout << "  Omega0      = " << best_ephem->Omega << "\n";
                        cout << "  Omega_dot   = " << best_ephem->Omega_dot << "\n";
                        cout << "  omega       = " << best_ephem->omega << "\n";
                        cout << "  Cuc, Cus    = " << best_ephem->C_uc << " , " << best_ephem->C_us << "\n";
                        cout << "  Cic, Cis    = " << best_ephem->C_ic << " , " << best_ephem->C_is << "\n";
                        cout << "  Crc, Crs    = " << best_ephem->C_rc << " , " << best_ephem->C_rs << "\n";
                        cout << "  Delta_n     = " << best_ephem->Delta_n << "\n";
                        cout << "  M0          = " << best_ephem->M_0 << "\n";

                        // 输出计算得到的坐标和中间变量
                        Point3D pos = best_ephem->calc_coordinate(t);

                        cout << "\n计算后的坐标：\n";
                        cout << "  X = " << pos.x << "\n";
                        cout << "  Y = " << pos.y << "\n";
                        cout << "  Z = " << pos.z << "\n";


                        cout << "===========================\n\n";
                    }
                    return 0;
                }

                
                // 计算卫星位置
                if(best_ephem){
                    Point3D pos = best_ephem->calc_coordinate(t);
                    sat.coordinates.push_back(pos);
                    sat.send_times.push_back(t);
                    sat.timediff_to_TOE.push_back(min_time_diff);

                    if(min_time_diff > 7200.0){//两小时有效期
                        //不在有效期内
                        cout << "警告: 卫星 " << sat.PRN << " 在t= " << t 
                        << " 处与使用的星历的轨道参数参考时间的时间差较大: " << min_time_diff << "秒" << endl;
                    }

                    outfile<<fixed<<setprecision(8);
                    outfile<<left<<setw(10)<<sat.PRN<<right<<setw(20)<<t<<setw(20)<<pos.x
                    <<setw(20)<<pos.y<<setw(20)<<pos.z<<setw(20)<<min_time_diff<<"\n";

                }
                
            }
        }
        cout << "卫星 " << sat.PRN << " 计算完成，共 " 
        << sat.coordinates.size() << " 个位置点" << endl;
    }
    cout<<Satellites[0].Ephemerys[0].C_ic;



}