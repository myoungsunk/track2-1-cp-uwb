from __future__ import annotations

import csv
import html
from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
OUT_DIR = ROOT / "reports"
OUT_DIR.mkdir(exist_ok=True)
OUT_PDF = OUT_DIR / "track2_1_cp_lp_integrated_review_10p_20260408.pdf"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def fnum(v: str, d: int = 3, nan_str: str = "NaN") -> str:
    try:
        x = float(v)
    except Exception:
        return nan_str
    if x != x:
        return nan_str
    return f"{x:.{d}f}"


def get_row(rows: list[dict[str, str]], **conds: str) -> dict[str, str]:
    for r in rows:
        ok = True
        for k, v in conds.items():
            if r.get(k) != v:
                ok = False
                break
        if ok:
            return r
    raise KeyError(f"Row not found for {conds}")


def ptxt(s: str) -> str:
    return html.escape(s).replace("\n", "<br/>")


def add_page_number(canvas, doc):
    canvas.saveState()
    canvas.setFont("MalgunGothic", 9)
    canvas.setFillColor(colors.grey)
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def main():
    # Font setup (Korean)
    font_path = Path(r"C:\Windows\Fonts\malgun.ttf")
    if not font_path.exists():
        raise FileNotFoundError("Korean font not found: C:\\Windows\\Fonts\\malgun.ttf")
    pdfmetrics.registerFont(TTFont("MalgunGothic", str(font_path)))

    summary_rows = read_csv_rows(RESULTS / "summary_table.csv")
    cf_rows = read_csv_rows(RESULTS / "counterfactual_table.csv")
    abl_rows = read_csv_rows(RESULTS / "fusion_ablation_table.csv")

    cp_a = get_row(summary_rows, Polarization="CP", Scenario="A")
    cp_b = get_row(summary_rows, Polarization="CP", Scenario="B")
    cp_c = get_row(summary_rows, Polarization="CP", Scenario="C")
    lp_a = get_row(summary_rows, Polarization="LP", Scenario="A")
    lp_b = get_row(summary_rows, Polarization="LP", Scenario="B")
    lp_c = get_row(summary_rows, Polarization="LP", Scenario="C")

    cfa_a_cp_cp = get_row(cf_rows, Scenario="A", Combo="CP_S1_CP_S2")
    cfa_a_lp_lp = get_row(cf_rows, Scenario="A", Combo="LP_S1_LP_S2")
    cfa_a_cp_lp = get_row(cf_rows, Scenario="A", Combo="CP_S1_LP_S2")
    cfa_a_lp_cp = get_row(cf_rows, Scenario="A", Combo="LP_S1_CP_S2")

    cfb_b_cp_cp = get_row(cf_rows, Scenario="B", Combo="CP_S1_CP_S2")
    cfb_b_cp_lp = get_row(cf_rows, Scenario="B", Combo="CP_S1_LP_S2")
    cfb_b_lp_cp = get_row(cf_rows, Scenario="B", Combo="LP_S1_CP_S2")
    cfc_c_cp_cp = get_row(cf_rows, Scenario="C", Combo="CP_S1_CP_S2")
    cfc_c_cp_lp = get_row(cf_rows, Scenario="C", Combo="CP_S1_LP_S2")

    ab_cp_a = get_row(abl_rows, Polarization="CP", Scenario="A")
    ab_cp_b = get_row(abl_rows, Polarization="CP", Scenario="B")
    ab_cp_c = get_row(abl_rows, Polarization="CP", Scenario="C")

    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    styles = getSampleStyleSheet()
    style_title = ParagraphStyle(
        "title_kr",
        parent=styles["Title"],
        fontName="MalgunGothic",
        fontSize=22,
        leading=30,
        alignment=1,
        textColor=colors.HexColor("#0A2E5D"),
        spaceAfter=8,
    )
    style_subtitle = ParagraphStyle(
        "subtitle_kr",
        parent=styles["Normal"],
        fontName="MalgunGothic",
        fontSize=11,
        leading=16,
        alignment=1,
        textColor=colors.HexColor("#2F3A4A"),
        spaceAfter=12,
    )
    style_h = ParagraphStyle(
        "h_kr",
        parent=styles["Heading2"],
        fontName="MalgunGothic",
        fontSize=14,
        leading=20,
        textColor=colors.HexColor("#153A7A"),
        spaceBefore=4,
        spaceAfter=6,
    )
    style_b = ParagraphStyle(
        "body_kr",
        parent=styles["Normal"],
        fontName="MalgunGothic",
        fontSize=10.5,
        leading=17,
        textColor=colors.black,
        wordWrap="CJK",
        spaceAfter=5,
    )
    style_bullet = ParagraphStyle(
        "bullet_kr",
        parent=style_b,
        leftIndent=14,
        firstLineIndent=-10,
        bulletIndent=0,
        spaceAfter=4,
    )

    doc = SimpleDocTemplate(
        str(OUT_PDF),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title="Track 2-1 CP vs LP 통합 리뷰",
        author="Codex Assisted Independent Review",
    )

    story = []

    # Page 1
    story.append(Paragraph(ptxt("Track 2-1 CP vs LP 검증 파이프라인<br/>독립 통합 리뷰 (10페이지)"), style_title))
    story.append(
        Paragraph(
            ptxt(
                "대상: myoungsunk/track2-1-cp-uwb (branch: track-2-1, entry: src/main_track2_1.m)\n"
                f"작성 시각: {now}\n"
                "범위: Axis 1~5 (신호처리 정합성, 실험설계 타당성, 재현성/소프트웨어 품질, 통계/보고 무결성, 적대적 리뷰) 통합"
            ),
            style_subtitle,
        )
    )
    story.append(Paragraph(ptxt("핵심 요약"), style_h))
    for b in [
        "원 설계 기준으로는 'CP → multipath rejection → S1 → S2 → S4'의 인과사슬이 직접 식별되지 않는다. S3는 병렬 지표이며 S1/S2를 구동하지 않는다.",
        "수치적으로 CP는 S2(DoA)와 S4(위치)에서 강한 우위가 재현된다. 그러나 이는 '편파의 순수 물리 효과'와 'RSSD-DoA 방식 적합성'이 혼합된 결과일 가능성이 높다.",
        f"최신 실행 기준 CP-A/B/C의 S1 RMSE는 {fnum(cp_a['Ranging_RMSE_m'])}/{fnum(cp_b['Ranging_RMSE_m'])}/{fnum(cp_c['Ranging_RMSE_m'])} m, S2 RMSE는 {fnum(cp_a['DoA_RMSE_deg'],1)}/{fnum(cp_b['DoA_RMSE_deg'],1)}/{fnum(cp_c['DoA_RMSE_deg'],1)} deg이다.",
        f"LP는 signed DoA 유효성 게이트 적용 시 S2 상관이 비유효(NaN)로 판정되어 S4가 NaN 처리된다. 이는 기존 abs(corr) 게이트가 숨기던 부호 문제를 노출한다.",
        "본 리뷰 반영 코드에서는 counterfactual 분석, fusion ablation, bootstrap CI, LoS/NLoS fail-fast, 실행 manifest를 추가해 보고 신뢰도를 높였다.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(Spacer(1, 8))
    story.append(
        Paragraph(
            ptxt(
                "정리하면, 본 저장소는 'CP가 현재 RSSD-DoA 구성에서 유리하다'는 결론까지는 강하게 지지한다. "
                "반면 '일반적 위치추정에서 CP의 보편 우위'를 주장하려면 다중 anchor/tilt, LP 대체 DoA, 실측 연동 검증이 추가되어야 한다."
            ),
            style_b,
        )
    )
    story.append(PageBreak())

    # Page 2
    story.append(Paragraph(ptxt("1) 신호처리 정합성 (Axis 1)"), style_h))
    story.append(
        Paragraph(
            ptxt(
                "S21(6.24–6.74 GHz, Δf=1 MHz, N=501) → windowed IFFT → CIR → FP 검출 → 거리의 수학 경로를 점검한 결과, "
                "주요 연산은 일관적이나 해석상 주의점이 뚜렷하다."
            ),
            style_b,
        )
    )
    for b in [
        "IFFT 시간축은 t=n/(Nfft·Δf), 거리축은 d=c·t(일방향)로 구현되어 있다. 현재 데이터가 S21 전송 채널이면 일방향 해석이 맞지만, 향후 monostatic 해석으로 바뀌면 c·t/2로 즉시 전환해야 한다.",
        "Hann window + zero-padding(Nfft=16384) 적용은 안정적이다. 다만 fp_search_start_m=0.3 m는 window mainlobe 및 조기 경로 손실 가능성과 함께 해석되어야 한다.",
        "FP 검출은 threshold 통과 후 local peak를 잡는 방식이다. strict leading-edge가 아니므로 비대칭 파형에서 양(+) 바이어스가 생길 수 있다.",
        "LUT가 전역 단조가 아니며 분기(segments=4)가 존재한다. 다행히 branch-aware inverse를 쓰지만, 단일 affine 해석은 의미가 제한적이다.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(Spacer(1, 8))
    t_data = [
        ["항목", "코드 동작", "평가"],
        ["시간/거리축", "d = c·t", "S21 전송 채널 가정에서는 타당"],
        ["FP 규칙", "threshold + local peak", "leading-edge 대비 지연 바이어스 위험"],
        ["LUT 역변환", "branch-aware", "비단조 문제를 우회하나 본질 해결은 아님"],
        ["DoA 유효성", "signed corr gate", "abs gate 대비 안전성 향상"],
    ]
    tbl = Table(t_data, colWidths=[35 * mm, 70 * mm, 55 * mm])
    tbl.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), "MalgunGothic"),
                ("FONTSIZE", (0, 0), (-1, -1), 9.2),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E9EEF8")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    story.append(tbl)
    story.append(PageBreak())

    # Page 3
    story.append(Paragraph(ptxt("1) 신호처리 정합성 상세: 오차 규모 및 교정"), style_h))
    story.append(
        Paragraph(
            ptxt(
                "정량 오차 관점에서 가장 중요한 것은 '검출 바이어스'와 '좌표/부호 규약'이다. "
                "이번 수정에서 거리 보정 훅과 부호 자동점검을 도입해 silent error를 줄였다."
            ),
            style_b,
        )
    )
    for b in [
        "S1에서 range_calibration 모드(none/fixed_offset/los_median)를 추가해 절대 오프셋을 분리했다. 보정 전/후 추정치 모두 저장해 재현 가능성을 확보했다.",
        "S2에서 corr gate를 signed 기준으로 전환했다. 음의 상관이 큰데 abs로 valid 처리되는 문제를 방지한다.",
        "sign_autoflip 진단을 추가해 guide 좌표계와 GT 좌표계의 부호 불일치를 조기 탐지한다.",
        "LUT non-monotonic 경고를 명시 출력해, 결과 해석 시 branch ambiguity를 숨기지 않도록 했다.",
        "S4 WLS는 수학적으로 존재하지만 CP 기준 개선폭이 작다(아래 페이지 참조). 즉, S4가 핵심 성능 원인이라기보다 S2 품질에 종속적이다.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(Spacer(1, 8))
    story.append(
        Paragraph(
            ptxt(
                "권고: FP 검출은 향후 leading-edge + sub-sample interpolation 병행 비교가 필요하다. "
                "또한 S21 기준의 reference plane offset을 문서화하고, 캘리브레이션 오프셋 값을 시나리오/편파별로 고정해 보고해야 한다."
            ),
            style_b,
        )
    )
    story.append(PageBreak())

    # Page 4
    story.append(Paragraph(ptxt("2) 실험 설계 타당성 (Axis 2)"), style_h))
    story.append(
        Paragraph(
            ptxt(
                "원 설계의 취약점은 '인과 분해 부재'였다. 본 반영에서 counterfactual 표를 추가해 "
                "S1 vs S2 기여를 분리할 수 있게 만들었다."
            ),
            style_b,
        )
    )
    cf_table_data = [
        ["시나리오", "조합", "S4 RMSE (m)"],
        ["A", "CP_S1_CP_S2", fnum(cfa_a_cp_cp["Pos_RMSE_m"])],
        ["A", "LP_S1_LP_S2", fnum(cfa_a_lp_lp["Pos_RMSE_m"])],
        ["A", "CP_S1_LP_S2", fnum(cfa_a_cp_lp["Pos_RMSE_m"])],
        ["A", "LP_S1_CP_S2", fnum(cfa_a_lp_cp["Pos_RMSE_m"])],
        ["B", "CP_S1_CP_S2", fnum(cfb_b_cp_cp["Pos_RMSE_m"])],
        ["B", "CP_S1_LP_S2", fnum(cfb_b_cp_lp["Pos_RMSE_m"])],
        ["B", "LP_S1_CP_S2", fnum(cfb_b_lp_cp["Pos_RMSE_m"])],
        ["C", "CP_S1_CP_S2", fnum(cfc_c_cp_cp["Pos_RMSE_m"])],
        ["C", "CP_S1_LP_S2", fnum(cfc_c_cp_lp["Pos_RMSE_m"])],
    ]
    cft = Table(cf_table_data, colWidths=[24 * mm, 56 * mm, 30 * mm])
    cft.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), "MalgunGothic"),
                ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E9EEF8")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ]
        )
    )
    story.append(cft)
    story.append(Spacer(1, 8))
    for b in [
        "해석: CP S1을 유지하고 LP S2로 교체하면 위치오차가 즉시 2 m대로 악화된다. 반대로 LP S1에서도 CP S2를 넣으면 0.5~0.76 m로 회복된다.",
        "즉, 현 파이프라인에서 하류 성능 지배항은 S2(DoA)이며 S1의 영향은 2차적이다.",
        "따라서 논문 claim은 'CP의 일반 우위'보다 'CP가 RSSD-DoA 체인을 성립시킨다'로 좁히는 것이 방어 가능하다.",
        "남은 약점: single-anchor, single-tilt(45°) 조건은 일반화 근거가 약하다. 최소한 tilt sweep(30/45/60°)과 2-anchor 실험이 필요하다.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(PageBreak())

    # Page 5
    story.append(Paragraph(ptxt("3) 재현성 및 소프트웨어 품질 (Axis 3)"), style_h))
    story.append(
        Paragraph(
            ptxt(
                "독립 재실행 관점에서 핵심은 '외부 경로 의존 제거', '실패 시 조용한 fallback 금지', "
                "'실행 컨텍스트 기록'이다. 이번 반영으로 해당 항목이 크게 보강되었다."
            ),
            style_b,
        )
    )
    score_table = Table(
        [
            ["차원", "초기 추정", "현재 상태", "근거"],
            ["재현성", "2/5", "4/5", "README + 상대경로 guide + run_manifest.json"],
            ["설정관리", "3/5", "4/5", "setup_config 중심 + 게이트/통계 옵션 명시"],
            ["테스트", "0/5", "3/5", "핵심 3개 테스트(run_all_tests) 추가"],
            ["추적성", "2/5", "4/5", "commit/branch/toolbox/seed 기록"],
            ["출력무결성", "3/5", "4/5", "counterfactual/fusion/CI 테이블 자동 생성"],
            ["문서화", "2/5", "4/5", "실행형 README 신설"],
        ],
        colWidths=[24 * mm, 22 * mm, 22 * mm, 77 * mm],
    )
    score_table.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), "MalgunGothic"),
                ("FONTSIZE", (0, 0), (-1, -1), 9.3),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E9EEF8")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    story.append(score_table)
    story.append(Spacer(1, 8))
    for b in [
        "LoS/NLoS 라벨 미존재 시 즉시 에러를 내도록 fail-fast 처리했다. 이는 B/C 시나리오가 전부 NLoS로 잘못 떨어지는 위험을 제거한다.",
        "테스트는 (i) synthetic delay IFFT, (ii) LoS strictness, (iii) signed DoA gate로 구성되어 회귀 안전망의 최소 골격을 확보했다.",
        "남은 과제는 CI 파이프라인(예: GitHub Actions MATLAB job)과 고정 결과 snapshot 검증이다.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(PageBreak())

    # Page 6
    story.append(Paragraph(ptxt("4) 통계 및 보고 무결성 (Axis 4)"), style_h))
    story.append(
        Paragraph(
            ptxt(
                "기존 보고의 핵심 문제는 (a) 유효숫자 과신, (b) tail metric의 불확실성 미표기, "
                "(c) invalid DoA 표본의 해석 누락이었다. 이를 bootstrap CI와 유효 샘플 수 컬럼으로 보완했다."
            ),
            style_b,
        )
    )
    for b in [
        f"CP-A S1 RMSE {fnum(cp_a['Ranging_RMSE_m'])} m의 95% CI는 [{fnum(cp_a['Ranging_RMSE_CI95_L_m'])}, {fnum(cp_a['Ranging_RMSE_CI95_U_m'])}] m이다. 단일 숫자 0.001 m 표기는 과도하다.",
        f"CP-B S2 RMSE {fnum(cp_b['DoA_RMSE_deg'],2)} deg의 95% CI는 [{fnum(cp_b['DoA_RMSE_CI95_L_deg'],2)}, {fnum(cp_b['DoA_RMSE_CI95_U_deg'],2)}] deg이다.",
        "LP는 signed gate에서 DoA corr가 NaN이므로 S4는 계산되지 않는다. 이는 '비기능 상태를 성능 비교에 포함'하는 오류를 줄인다.",
        "P90/CEP는 n=56에서 표본변동성이 크므로 본문에는 점추정+CI를 함께 제시해야 한다.",
        "권장 보고 형식: RMSE(95% CI), P90(95% CI), bias, 유효샘플 n, 게이트 정책(signed/abs) 명시.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(Spacer(1, 8))
    story.append(
        Paragraph(
            ptxt(
                "추가 권고: RMSE^2 = bias^2 + variance 분해를 본문 도표로 제시하고, "
                "LP의 DoA 분포는 KS test(균등성 가설) 또는 rank 기반 지표로 별도 진단하는 것이 정직한 보고에 가깝다."
            ),
            style_b,
        )
    )
    story.append(PageBreak())

    # Page 7
    story.append(Paragraph(ptxt("5) 적대적 리뷰 (Axis 5): 거절 사유와 반증 조건"), style_h))
    story.append(
        Paragraph(
            ptxt(
                "상위 저널 리뷰어 시각에서 치명도 높은 반론을 정리하고, 각 반론을 깨기 위한 최소 증거를 제시한다."
            ),
            style_b,
        )
    )
    objections = [
        "반론 1: 결과는 편파가 아니라 RSSD-DoA 방법 선택의 산물이다. / 반증: LP 대체 DoA(phase/monopulse/MUSIC)와 동일 조건 비교.",
        "반론 2: single-anchor+45° tilt는 cherry-picking이다. / 반증: tilt sweep + anchor 배치 sweep + 2-anchor 결과.",
        "반론 3: MRR 차이(약 0.5 dB)가 S2/S4 대격차를 설명 못 한다. / 반증: 중간 메커니즘(peak sharpness, first-bounce rejection) 정량 모델.",
        "반론 4: S1 양의 바이어스는 캘리브레이션 오류다. / 반증: reference plane 보정 및 보정 전/후 오차분해 제시.",
        "반론 5: WLS는 과장된 라벨이다. / 반증: direct 대비 의미 있는 일관 개선(현재는 CP에서도 개선폭 작음).",
        "반론 6: B 시나리오 LoS/NLoS 역전 해석이 부실하다. / 반증: 표본수 기반 CI+물리 설명+라벨 검증 로그.",
        "반론 7: LP는 '열등'이 아니라 '비기능'이다. / 반증: 기능하는 LP baseline을 포함하거나 claim 축소.",
        "반론 8: 단일 결정론 시뮬레이션은 불충분하다. / 반증: SNR sweep Monte Carlo 다회 실행.",
        "반론 9: 실측 연결이 없다. / 반증: 최소 1개 실내 측정 셋으로 방향성 검증.",
        "반론 10: 4-stage chain 설명이 post-hoc다. / 반증: stage interventional 분석(counterfactual) 본문 편입.",
    ]
    for ob in objections:
        story.append(Paragraph(ptxt(ob), style_bullet, bulletText="•"))
    story.append(PageBreak())

    # Page 8
    story.append(Paragraph(ptxt("통합 BLOCKER/MAJOR 상태표 (코드 반영 기준)"), style_h))
    status_tbl = Table(
        [
            ["이슈", "심각도", "현재 상태", "근거/산출물"],
            ["DoA abs gate", "BLOCKER", "해결", "signed gate + is_doa_valid_for_positioning"],
            ["LoS 라벨 fallback", "BLOCKER", "해결", "require_external + count assert"],
            ["인과 분해 부재", "BLOCKER", "부분해결", "counterfactual_table.csv 추가"],
            ["WLS 실효성 불명", "MAJOR", "부분해결", "fusion_ablation_table.csv 추가"],
            ["통계 CI 부재", "BLOCKER", "해결", "summary_table에 bootstrap CI 추가"],
            ["재현성 manifest 부재", "MAJOR", "해결", "run_manifest.json 생성"],
            ["LP 공정 baseline 부재", "BLOCKER", "미해결", "LP 대체 DoA 실험 필요"],
            ["일반화(tilt/anchor sweep)", "BLOCKER", "미해결", "추가 HFSS run 필요"],
            ["실측 연동 검증 부재", "BLOCKER", "미해결", "measurement sanity check 필요"],
        ],
        colWidths=[48 * mm, 18 * mm, 22 * mm, 57 * mm],
    )
    status_tbl.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), "MalgunGothic"),
                ("FONTSIZE", (0, 0), (-1, -1), 9.1),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E9EEF8")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    story.append(status_tbl)
    story.append(Spacer(1, 8))
    story.append(
        Paragraph(
            ptxt(
                "중요: 코드 보강은 '해석 신뢰도'를 올렸지만, 실험 공간 자체를 넓히지는 못한다. "
                "즉 미해결 BLOCKER는 추가 시뮬레이션/측정 데이터 확보 없이는 닫히지 않는다."
            ),
            style_b,
        )
    )
    story.append(PageBreak())

    # Page 9
    story.append(Paragraph(ptxt("최신 실행 결과 해석 (2026-04-08 재실행)"), style_h))
    for b in [
        f"CP 성능: S1 RMSE A/B/C = {fnum(cp_a['Ranging_RMSE_m'])}/{fnum(cp_b['Ranging_RMSE_m'])}/{fnum(cp_c['Ranging_RMSE_m'])} m, "
        f"S2 RMSE = {fnum(cp_a['DoA_RMSE_deg'],1)}/{fnum(cp_b['DoA_RMSE_deg'],1)}/{fnum(cp_c['DoA_RMSE_deg'],1)} deg, "
        f"S4 RMSE = {fnum(cp_a['Pos_RMSE_m'])}/{fnum(cp_b['Pos_RMSE_m'])}/{fnum(cp_c['Pos_RMSE_m'])} m.",
        f"LP 성능: S2 RMSE는 {fnum(lp_a['DoA_RMSE_deg'],1)} deg 수준이지만 signed corr가 NaN으로 판정되어 S4는 NaN 처리된다.",
        "Counterfactual에서 CP_S1_LP_S2가 LP_S1_LP_S2와 유사하게 악화되고, LP_S1_CP_S2는 CP_S1_CP_S2에 근접한다. 이는 S2 지배 가설을 강하게 지지한다.",
        f"WLS ablation(CP): Delta_RMSE A/B/C = {fnum(ab_cp_a['Delta_RMSE_m'],4)}/{fnum(ab_cp_b['Delta_RMSE_m'],4)}/{fnum(ab_cp_c['Delta_RMSE_m'],4)} m.",
        "해석: WLS는 존재하나 기여는 제한적이며, 전체 개선의 주원인은 DoA 유효성/단조구간 선택에 있다.",
        f"MRR 평균은 CP A/B/C = {fnum(cp_a['MRR_mean_dB'],3)}/{fnum(cp_b['MRR_mean_dB'],3)}/{fnum(cp_c['MRR_mean_dB'],3)} dB, "
        f"LP A/B/C = {fnum(lp_a['MRR_mean_dB'],3)}/{fnum(lp_b['MRR_mean_dB'],3)}/{fnum(lp_c['MRR_mean_dB'],3)} dB로 차이가 크지 않다.",
        "따라서 'MRR 단독 메커니즘'은 정량적으로 부족하며, 추가 기전 지표를 본문에 병렬 제시해야 한다.",
    ]:
        story.append(Paragraph(ptxt(b), style_bullet, bulletText="•"))
    story.append(Spacer(1, 8))
    story.append(
        Paragraph(
            ptxt(
                "요약: 현재 데이터셋 안에서 가장 방어 가능한 메시지는 "
                "'CP가 본 RSSD-DoA 파이프라인을 기능하게 만들고, 그 효과가 S4로 전달된다'이다."
            ),
            style_b,
        )
    )
    story.append(PageBreak())

    # Page 10
    story.append(Paragraph(ptxt("제출 전 실행 TODO (Must Fix / Strengthen)"), style_h))
    story.append(Paragraph(ptxt("Must Fix Before Publication"), style_h))
    must_fix = [
        "LP 대체 DoA baseline(phase/monopulse/MUSIC 중 최소 1개) 추가 및 CP와 동등 비교.",
        "tilt(30/45/60°) + anchor 배치 + 2-anchor 확장 실험으로 일반화 근거 확보.",
        "SNR sweep Monte Carlo로 RMSE/P90/CEP의 신뢰구간 보고.",
        "MRR 외 메커니즘 지표(peak sharpness, first-bounce rejection 등) 추가.",
        "실측 sanity check(최소 1개 환경)로 SBR+ 편향 가능성 점검.",
    ]
    for m in must_fix:
        story.append(Paragraph(ptxt(m), style_bullet, bulletText="•"))

    story.append(Paragraph(ptxt("Would Strengthen the Paper"), style_h))
    strengthen = [
        "RMSE^2 = bias^2 + variance 분해 도표를 S1/S2/S4에 일괄 적용.",
        "DoA 분포 진단(KS test, circular metric) 추가.",
        "모든 그림/표에 유효샘플 수(n_valid)와 gate 정책(signed)을 캡션에 명시.",
        "재현성 패키지: run_manifest + 실행 명령 + 테스트 로그를 부록으로 제공.",
    ]
    for s in strengthen:
        story.append(Paragraph(ptxt(s), style_bullet, bulletText="•"))

    story.append(Spacer(1, 10))
    story.append(
        Paragraph(
            ptxt(
                "부록(생성 파일)\n"
                "- results/summary_table.csv (CI 포함)\n"
                "- results/counterfactual_table.csv\n"
                "- results/fusion_ablation_table.csv\n"
                "- results/run_manifest.json\n"
                "- tests/run_all_tests.m"
            ),
            style_b,
        )
    )
    story.append(Spacer(1, 6))
    story.append(
        Paragraph(
            ptxt(
                "결론 문구(권장): '본 연구는 현재 RSSD-DoA 기반 단일-anchor 체인에서 CP의 실효 우위를 확인했다. "
                "다만 편파 일반 우위 주장은 다중 기하/다중 방법/실측 검증으로 추가 확인이 필요하다.'"
            ),
            style_b,
        )
    )

    doc.build(story, onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(str(OUT_PDF))


if __name__ == "__main__":
    main()

