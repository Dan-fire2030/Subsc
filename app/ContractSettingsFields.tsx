"use client";

import {
  BellRing,
  CalendarRange,
  ChevronDown,
} from "lucide-react";
import {
  notificationEventLabels,
  type ContractSettings,
  type NotificationEvent,
} from "../db/contract-settings";

const leadDayOptions = [0, 1, 3, 7, 14, 30];
const leadHourOptions = [1, 3, 6, 12];

export function ContractSettingsFields({
  value,
  onChange,
}: {
  value: ContractSettings;
  onChange: (value: ContractSettings) => void;
}) {
  function patch(next: Partial<ContractSettings>) {
    onChange({ ...value, ...next });
  }

  function toggleEvent(event: NotificationEvent) {
    onChange({
      ...value,
      notifications: {
        ...value.notifications,
        events: {
          ...value.notifications.events,
          [event]: !value.notifications.events[event],
        },
      },
    });
  }

  function toggleLeadDay(day: number) {
    const selected = value.notifications.leadDays.includes(day);
    onChange({
      ...value,
      notifications: {
        ...value.notifications,
        leadDays: selected
          ? value.notifications.leadDays.filter((item) => item !== day)
          : [...value.notifications.leadDays, day].sort((a, b) => a - b),
      },
    });
  }

  return (
    <section className={`contract-card ${value.enabled ? "is-open" : ""}`}>
      <div className="contract-toggle-row">
        <span className="contract-icon"><CalendarRange size={19} /></span>
        <span>
          <strong>契約期間を設定</strong>
          <small>開始日・終了条件を管理</small>
        </span>
        <button
          className={`ios-switch ${value.enabled ? "is-on" : ""}`}
          type="button"
          role="switch"
          aria-checked={value.enabled}
          aria-label="契約期間の設定を切り替える"
          onClick={() => patch({ enabled: !value.enabled })}
        >
          <span />
        </button>
      </div>

      {value.enabled ? (
        <div className="contract-level-two">
          <div className="field-row">
            <label>
              利用開始日
              <input
                type="date"
                value={value.startDate}
                onChange={(event) => patch({ startDate: event.target.value })}
              />
            </label>
            <label>
              課金開始日
              <input
                type="date"
                value={value.billingStartDate}
                onChange={(event) =>
                  patch({ billingStartDate: event.target.value })
                }
              />
            </label>
          </div>

          <label>
            終了設定
            <select
              value={value.endMode}
              onChange={(event) =>
                patch({
                  endMode: event.target.value as ContractSettings["endMode"],
                })
              }
            >
              <option value="none">終了日なし</option>
              <option value="date">終了日を指定</option>
              <option value="payments">支払い回数で終了</option>
            </select>
          </label>

          {value.endMode === "date" ? (
            <label>
              終了日
              <input
                type="date"
                value={value.endDate}
                onChange={(event) => patch({ endDate: event.target.value })}
              />
            </label>
          ) : null}

          {value.endMode === "payments" ? (
            <div className="field-row">
              <label>
                合計支払い回数
                <input
                  type="number"
                  min="1"
                  max="999"
                  inputMode="numeric"
                  value={value.totalPayments || ""}
                  placeholder="12"
                  onChange={(event) =>
                    patch({ totalPayments: Number(event.target.value) })
                  }
                />
              </label>
              <label>
                支払い済み回数
                <input
                  type="number"
                  min="0"
                  max="999"
                  inputMode="numeric"
                  value={value.completedPayments || ""}
                  placeholder="0"
                  onChange={(event) =>
                    patch({ completedPayments: Number(event.target.value) })
                  }
                />
              </label>
            </div>
          ) : null}

          <details className="advanced-settings">
            <summary>
              <span>
                <strong>詳細設定</strong>
                <small>無料体験・解約期限・通知など</small>
              </span>
              <ChevronDown size={18} aria-hidden="true" />
            </summary>

            <div className="advanced-content">
              <div className="setting-group">
                <p className="setting-group-title">契約条件</p>
                <label>
                  無料体験終了日
                  <input
                    type="date"
                    value={value.freeTrialEndDate}
                    onChange={(event) =>
                      patch({ freeTrialEndDate: event.target.value })
                    }
                  />
                </label>
                <div className="field-row">
                  <label>
                    契約期間
                    <select
                      value={value.contractTerm}
                      onChange={(event) =>
                        patch({
                          contractTerm: event.target
                            .value as ContractSettings["contractTerm"],
                        })
                      }
                    >
                      <option value="none">指定なし</option>
                      <option value="1_month">1か月</option>
                      <option value="1_year">1年</option>
                      <option value="2_years">2年</option>
                      <option value="custom">終了日を指定</option>
                    </select>
                  </label>
                  {value.contractTerm === "custom" ? (
                    <label>
                      契約期間の終了日
                      <input
                        type="date"
                        value={value.contractTermEndDate}
                        onChange={(event) =>
                          patch({ contractTermEndDate: event.target.value })
                        }
                      />
                    </label>
                  ) : (
                    <label>
                      最低利用期間の終了日
                      <input
                        type="date"
                        value={value.minimumTermEndDate}
                        onChange={(event) =>
                          patch({ minimumTermEndDate: event.target.value })
                        }
                      />
                    </label>
                  )}
                </div>
                {value.contractTerm === "custom" ? (
                  <label>
                    最低利用期間の終了日
                    <input
                      type="date"
                      value={value.minimumTermEndDate}
                      onChange={(event) =>
                        patch({ minimumTermEndDate: event.target.value })
                      }
                    />
                  </label>
                ) : null}
              </div>

              <div className="setting-group">
                <p className="setting-group-title">更新方法</p>
                <label>
                  更新方式
                  <select
                    value={value.renewalMode}
                    onChange={(event) =>
                      patch({
                        renewalMode: event.target
                          .value as ContractSettings["renewalMode"],
                      })
                    }
                  >
                    <option value="automatic">自動更新</option>
                    <option value="manual">手動更新</option>
                    <option value="none">更新なし</option>
                  </select>
                </label>
                {value.renewalMode !== "none" ? (
                  <div className="interval-row">
                    <label>
                      更新間隔
                      <input
                        type="number"
                        min="1"
                        max="999"
                        inputMode="numeric"
                        value={value.renewalIntervalValue}
                        onChange={(event) =>
                          patch({
                            renewalIntervalValue: Number(event.target.value),
                          })
                        }
                      />
                    </label>
                    <label>
                      単位
                      <select
                        value={value.renewalIntervalUnit}
                        onChange={(event) =>
                          patch({
                            renewalIntervalUnit: event.target
                              .value as ContractSettings["renewalIntervalUnit"],
                          })
                        }
                      >
                        <option value="days">日ごと</option>
                        <option value="months">か月ごと</option>
                        <option value="years">年ごと</option>
                      </select>
                    </label>
                  </div>
                ) : null}
              </div>

              <div className="setting-group">
                <p className="setting-group-title">解約・終了</p>
                <div className="field-row">
                  <label>
                    解約申請日
                    <input
                      type="date"
                      value={value.cancellationRequestedDate}
                      onChange={(event) =>
                        patch({
                          cancellationRequestedDate: event.target.value,
                        })
                      }
                    />
                  </label>
                  <label>
                    解約期限
                    <select
                      value={value.cancellationDeadlineMode}
                      onChange={(event) =>
                        patch({
                          cancellationDeadlineMode: event.target
                            .value as ContractSettings["cancellationDeadlineMode"],
                        })
                      }
                    >
                      <option value="none">指定なし</option>
                      <option value="date">日付を指定</option>
                      <option value="days_before">更新日の○日前</option>
                    </select>
                  </label>
                </div>
                {value.cancellationDeadlineMode === "date" ? (
                  <label>
                    解約期限日
                    <input
                      type="date"
                      value={value.cancellationDeadlineDate}
                      onChange={(event) =>
                        patch({ cancellationDeadlineDate: event.target.value })
                      }
                    />
                  </label>
                ) : null}
                {value.cancellationDeadlineMode === "days_before" ? (
                  <label>
                    更新日の何日前まで
                    <input
                      type="number"
                      min="0"
                      max="365"
                      inputMode="numeric"
                      value={value.cancellationDeadlineDaysBefore}
                      onChange={(event) =>
                        patch({
                          cancellationDeadlineDaysBefore: Number(
                            event.target.value,
                          ),
                        })
                      }
                    />
                  </label>
                ) : null}
                <div className="field-row">
                  <label>
                    終了理由
                    <select
                      value={value.endReason}
                      onChange={(event) =>
                        patch({
                          endReason: event.target
                            .value as ContractSettings["endReason"],
                        })
                      }
                    >
                      <option value="none">未設定</option>
                      <option value="canceled">解約</option>
                      <option value="trial_ended">無料期間終了</option>
                      <option value="service_ended">サービス終了</option>
                      <option value="switched">乗り換え</option>
                      <option value="other">その他</option>
                    </select>
                  </label>
                  <label>
                    終了後
                    <select
                      value={value.endBehavior}
                      onChange={(event) =>
                        patch({
                          endBehavior: event.target
                            .value as ContractSettings["endBehavior"],
                        })
                      }
                    >
                      <option value="keep">再契約候補として残す</option>
                      <option value="archive">履歴として保存</option>
                      <option value="hide">一覧から非表示</option>
                    </select>
                  </label>
                </div>
                {value.endReason === "other" ? (
                  <label>
                    終了理由のメモ
                    <input
                      type="text"
                      maxLength={100}
                      value={value.endReasonNote}
                      placeholder="理由を入力"
                      onChange={(event) =>
                        patch({ endReasonNote: event.target.value })
                      }
                    />
                  </label>
                ) : null}
              </div>

              <div className="setting-group notification-settings">
                <div className="notification-heading">
                  <span><BellRing size={18} /></span>
                  <div>
                    <strong>アプリ内通知</strong>
                    <small>Subscを開いた時に期限をお知らせ</small>
                  </div>
                  <button
                    className={`ios-switch ${value.notifications.enabled ? "is-on" : ""}`}
                    type="button"
                    role="switch"
                    aria-checked={value.notifications.enabled}
                    aria-label="アプリ内通知を切り替える"
                    onClick={() =>
                      onChange({
                        ...value,
                        notifications: {
                          ...value.notifications,
                          enabled: !value.notifications.enabled,
                        },
                      })
                    }
                  >
                    <span />
                  </button>
                </div>

                {value.notifications.enabled ? (
                  <>
                    <fieldset className="choice-field">
                      <legend>通知する内容</legend>
                      <div className="check-grid">
                        {(Object.keys(notificationEventLabels) as NotificationEvent[]).map(
                          (event) => (
                            <label key={event} className="check-item">
                              <input
                                type="checkbox"
                                checked={value.notifications.events[event]}
                                onChange={() => toggleEvent(event)}
                              />
                              <span>{notificationEventLabels[event]}</span>
                            </label>
                          ),
                        )}
                      </div>
                    </fieldset>
                    <fieldset className="choice-field">
                      <legend>通知タイミング（複数選択可）</legend>
                      <div className="lead-day-grid">
                        {leadDayOptions.map((day) => (
                          <button
                            key={day}
                            type="button"
                            className={
                              value.notifications.leadDays.includes(day)
                                ? "is-selected"
                                : ""
                            }
                            aria-pressed={value.notifications.leadDays.includes(day)}
                            onClick={() => toggleLeadDay(day)}
                          >
                            {day === 0 ? "当日" : `${day}日前`}
                          </button>
                        ))}
                      </div>
                    </fieldset>
                    <fieldset className="choice-field">
                      <legend>時間単位の通知（複数選択可）</legend>
                      <div className="lead-day-grid lead-hour-grid">
                        {leadHourOptions.map((hour) => (
                          <button
                            key={hour}
                            type="button"
                            className={
                              value.notifications.leadHours.includes(hour)
                                ? "is-selected"
                                : ""
                            }
                            aria-pressed={value.notifications.leadHours.includes(hour)}
                            onClick={() => {
                              const selected =
                                value.notifications.leadHours.includes(hour);
                              onChange({
                                ...value,
                                notifications: {
                                  ...value.notifications,
                                  leadHours: selected
                                    ? value.notifications.leadHours.filter(
                                        (item) => item !== hour,
                                      )
                                    : [
                                        ...value.notifications.leadHours,
                                        hour,
                                      ].sort((a, b) => a - b),
                                },
                              });
                            }}
                          >
                            {hour}時間前
                          </button>
                        ))}
                      </div>
                    </fieldset>
                    <label>
                      通知対象の時刻
                      <input
                        type="time"
                        value={value.notifications.time}
                        onChange={(event) =>
                          onChange({
                            ...value,
                            notifications: {
                              ...value.notifications,
                              time: event.target.value,
                            },
                          })
                        }
                      />
                    </label>
                  </>
                ) : null}
              </div>
            </div>
          </details>
        </div>
      ) : null}
    </section>
  );
}
