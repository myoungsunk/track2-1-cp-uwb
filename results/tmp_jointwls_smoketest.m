addpath('D:/OneDrive - postech.ac.kr/명선/2026/2. ISAC/track3-cp-uwb-reliability_tilted2rx_project_20260406/src');
cfg=setup_config();
cfg.guide.cp_csv='E:/0. CP Antenna/CP_sbr_re/0.step1_ranging+Los/inc_ang_RSSD_validation_patch_height=1m_23R1.csv';
cfg.guide.cp_csv_candidates={cfg.guide.cp_csv};
cfg.doa.inverse_mode_by_pol.CP='branch_aware';
cfg.doa.segment_filter.by_pol.CP.enabled=false;
cfg.doa.slope_conditioning.by_pol.CP.enabled=false;

d=load_case_data('CP','A',cfg); s1=stage1_ranging(d,cfg); s2=stage2_doa(d,cfg);

cfg1=cfg; cfg1.fusion.doa_hypothesis_mode='single';
s4s=stage4_positioning(s1,s2,d,cfg1);

cfg2=cfg; cfg2.fusion.doa_hypothesis_mode='joint_wls';
s4j=stage4_positioning(s1,s2,d,cfg2);

fprintf('single pos rmse=%.6f, joint pos rmse=%.6f\n', s4s.rmse_m, s4j.rmse_m);
fprintf('joint used ratio=%.6f, mean candidates=%.6f\n', mean(s4j.used_joint_theta_selection), mean(s4j.theta_candidate_count));
