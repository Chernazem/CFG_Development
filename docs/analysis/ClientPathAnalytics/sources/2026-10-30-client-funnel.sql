WITH
params AS (
    SELECT
        DATE '2026-09-01' AS date_from,
        DATE '2026-10-27' AS date_to,       -- не включительно
        26::integer       AS max_day_of_month,
        DATE '2026-10-27' AS as_of_date
),

/* ============================================================
   Справочник решений МПР
   ============================================================ */
solution_map AS (
    SELECT *
    FROM (
        VALUES
            (
                '6d9f5ec1-2693-11f1-b823-30e1716b90ff'::uuid,
                'SELF_EMPLOYED',
                'Кредитная линия для самозанятого',
                'CREDIT_LINE',
                'PRODUCT'
            ),
            (
                '6d9f5ebf-2693-11f1-b823-30e1716b90ff'::uuid,
                'INDIVIDUAL_ENTREPRENEUR',
                'Кредитная линия для ИП',
                'CREDIT_LINE',
                'PRODUCT'
            ),
            (
                '6d9f5ec0-2693-11f1-b823-30e1716b90ff'::uuid,
                'REFINANCING',
                'Рефинансирование',
                'REFINANCING',
                'PRODUCT'
            ),
            (
                '6d9f5ec3-2693-11f1-b823-30e1716b90ff'::uuid,
                'INCOME_CERT',
                'Справка о доходах',
                'INCOME_CERT',
                'INTERMEDIATE'
            ),
            (
                '6d9f5ec2-2693-11f1-b823-30e1716b90ff'::uuid,
                'LOAN_REDUCTION',
                'Снижение суммы займа',
                'LOAN_REDUCTION',
                'PRODUCT'
            ),
            (
                '3d20aefa-73a3-4641-8cd1-44fd986224b1'::uuid,
                'CONSUMER_LOAN',
                'Потребительский заём',
                'CONSUMER_LOAN',
                'PRODUCT'
            ),
            (
                'ee2997ee-281a-4d73-bf69-2846f1883da4'::uuid,
                'AUTOZAIM',
                'Автозайм',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                '03aafbd5-d00b-4b47-84e4-7997f7305c82'::uuid,
                'AUTOZAIM_IP',
                'Автозайм для ИП',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                '43d68f67-82a8-4683-b85f-5f88848bc116'::uuid,
                'AUTOZAIM_SELF_EMPLOYED',
                'Автозайм для самозанятого',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                '5cbd71bd-43ac-4730-8cbb-8a8aad064027'::uuid,
                'CREDIT_LINE',
                'Кредитная линия ПСК до 200%',
                'CREDIT_LINE',
                'PRODUCT'
            ),
            (
                'de73aaae-118d-4f7a-9d42-efb248126532'::uuid,
                'CREDIT_LINE_REDUCED_LIMIT',
                'Кредитная линия со сниженным лимитом',
                'CREDIT_LINE',
                'PRODUCT'
            ),
            (
                '5c06d597-3da9-4be0-9fdc-7e5a22c78321'::uuid,
                'CREDIT_LINE_PSK_LIMIT_REDUCTION',
                'Кредитная линия ПСК до 200% и снижение лимита',
                'CREDIT_LINE',
                'PRODUCT'
            ),
            (
                '1c886e43-f2bf-4bcc-adda-8bec3b0de019'::uuid,
                'BANKRUPTCY',
                'Банкротство физического лица',
                'BANKRUPTCY',
                'CONSULTING'
            )
    ) AS s(
        solution_id,
        solution_code,
        solution_name,
        solution_family,
        solution_group
    )
),

/* ============================================================
   Белый список целевых операций

   PRODUCT — продуктовая заявка.
   INTERMEDIATE — промежуточный сценарий.
   ============================================================ */
target_operations AS (
    SELECT *
    FROM (
        VALUES
            (
                'ПодтверждениеДохода',
                'INCOME_CERT',
                'INTERMEDIATE'
            ),

            (
                'Рефинансирование',
                'REFINANCING',
                'PRODUCT'
            ),
            (
                'РефинансированиеБезДокументовОнлайн',
                'REFINANCING',
                'PRODUCT'
            ),

            (
                'ОформлениеКредитнойЛинии',
                'CREDIT_LINE',
                'PRODUCT'
            ),
            (
                'ОформлениеКредитнойЛинииОнлайн',
                'CREDIT_LINE',
                'PRODUCT'
            ),

            (
                'ВыдачаОнлайн',
                'LOAN_REDUCTION',
                'PRODUCT'
            ),
            (
                'ВыдачаОнлайнНовомуКлиенту',
                'OTHER_LOAN',
                'PRODUCT'
            ),
            (
                'ДистанционнаяВыдача',
                'OTHER_LOAN',
                'PRODUCT'
            ),

            (
                'Долгосрочный',
                'LONG_TERM',
                'PRODUCT'
            ),
            (
                'ДолгосрочныйПослеСогласования',
                'LONG_TERM',
                'PRODUCT'
            ),
            (
                'ДолгосрочныйПоТелефону',
                'LONG_TERM',
                'PRODUCT'
            ),
            (
                'ДолгосрочныйПоТелефонуПослеСогласования',
                'LONG_TERM',
                'PRODUCT'
            ),

            (
                'ЗаключениеДоговораЗайма',
                'CONSUMER_LOAN',
                'PRODUCT'
            ),

            (
                'АвтоЗайм',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                'АвтоЗаймПослеСогласования',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                'АвтоЗаймПоТелефону',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                'АвтоЗаймПоТелефонуПослеСогласования',
                'AUTOZAIM',
                'PRODUCT'
            ),

            (
                'ВыдачаПодПТС',
                'AUTOZAIM',
                'PRODUCT'
            ),
            (
                'ВыдачаПодПТСНовомуКлиенту',
                'AUTOZAIM',
                'PRODUCT'
            )
    ) AS t(
        operation_name,
        operation_family,
        operation_group
    )
),

/* ============================================================
   Предварительные заявки
   ============================================================ */
preapplications AS (
    SELECT
        rfl.id AS preapplication_id,
        rfl.dt AS preapplication_dt,
        rfl.dt::date AS event_date,
        rfl.counterparty_id,
        c.code AS client_code,
        rfl.number AS preapplication_number,
        rfl.amount_requested,
        rfl.step_id,
        rfl.reason_for_refusal_in_loan_id,
        rfril.name AS preapplication_refusal_reason,
        rfl.comment_reject_reason,
        rfl.is_new_counterparty,

        COALESCE(dsc.channel_name, 'Офис')
            AS sales_channel,

        CASE
            WHEN dsc.channel_name IN (
                'Безналично в офисе',
                'Наличными в офисе'
            )
                THEN 'Офис'

            WHEN dsc.channel_name IN (
                'В личном кабинете',
                'Рефинансирование в ЛК',
                'В личном кабинете - Стейдж'
            )
                THEN 'ЛК'

            WHEN dsc.channel_name IN (
                'mobileapp-android-flutter',
                'mobileapp-ios-flutter',
                'Мобильное приложение',
                'Мобильное приложение (Android)',
                'Мобильное приложение (IOS)'
            )
                THEN 'Моб. приложение'

            ELSE COALESCE(
                dsc.channel_name,
                'Офис'
            )
        END AS channel,

        CASE
            WHEN dd.tribe IN (
                'Трайб ВД',
                'Трайб Онлайн'
            )
                THEN 'Трайб ВД'
            ELSE 'Розница'
        END AS tribe,

        dd.squad,
        dd.division,

        CASE
            WHEN rfl.is_new_counterparty IS TRUE
                THEN 'Новый клиент'
            ELSE 'Повторный клиент'
        END AS client_type,

        /* Сырые признаки шага. */
        rfl.step_id IN (
            'e3591cce-360b-11e7-80b9-fa9538801de8'::uuid,
            'e3591ccd-360b-11e7-80b9-fa9538801de8'::uuid
        ) AS preapplication_success_step,

        rfl.step_id =
            '5653d0ee-3c0d-11e7-80bf-a57f9d7a28fd'::uuid
            AS preapplication_refusal_step,

        rfl.reason_for_refusal_in_loan_id IS NOT NULL
            AS preapplication_have_refusal_reason,

        /* Отказ имеет приоритет над успешным шагом. */
        (
            rfl.step_id =
                '5653d0ee-3c0d-11e7-80bf-a57f9d7a28fd'::uuid
            OR rfl.reason_for_refusal_in_loan_id IS NOT NULL
        ) AS preapplication_refused,

        (
            rfl.step_id IN (
                'e3591cce-360b-11e7-80b9-fa9538801de8'::uuid,
                'e3591ccd-360b-11e7-80b9-fa9538801de8'::uuid
            )
            AND rfl.reason_for_refusal_in_loan_id IS NULL
        ) AS preapplication_success,

        (
            rfl.step_id IN (
                'e3591cce-360b-11e7-80b9-fa9538801de8'::uuid,
                'e3591ccd-360b-11e7-80b9-fa9538801de8'::uuid,
                '5653d0ee-3c0d-11e7-80bf-a57f9d7a28fd'::uuid
            )
            OR rfl.reason_for_refusal_in_loan_id IS NOT NULL
        ) AS preapplication_finished,

        (
            rfl.step_id IN (
                'e3591cce-360b-11e7-80b9-fa9538801de8'::uuid,
                'e3591ccd-360b-11e7-80b9-fa9538801de8'::uuid
            )
            AND rfl.reason_for_refusal_in_loan_id IS NOT NULL
        ) AS anomaly_success_step_with_refusal_reason,

        CASE
            WHEN
                rfl.reason_for_refusal_in_loan_id IS NOT NULL
                OR rfl.step_id =
                   '5653d0ee-3c0d-11e7-80bf-a57f9d7a28fd'::uuid
                THEN 'Отказана'

            WHEN rfl.step_id IN (
                'e3591cce-360b-11e7-80b9-fa9538801de8'::uuid,
                'e3591ccd-360b-11e7-80b9-fa9538801de8'::uuid
            )
                THEN 'Успешно завершена'

            ELSE 'Не завершена'
        END AS preapplication_result

    FROM public.request_for_loan rfl

    CROSS JOIN params p

    LEFT JOIN public.counterparties c
        ON c.id = rfl.counterparty_id

    LEFT JOIN public.reasons_for_refusal_in_loan rfril
        ON rfril.id =
           rfl.reason_for_refusal_in_loan_id

    LEFT JOIN dash.dict_division dd
        ON dd.division_id = rfl.subdivision_id

    LEFT JOIN dash.dict_sales_channel dsc
        ON dsc.channel_id = rfl.chanel_sales_id

    WHERE rfl.kind_of_operation = 'Предварительная'
   -- and rfl.counterparty_id = 'b8b44768-39db-11ef-b821-3cfdfed12dbc'
      AND rfl.marker_delete IS FALSE
      AND rfl.counterparty_id IS NOT NULL
      AND rfl.dt >= p.date_from
      AND rfl.dt < p.date_to
      AND EXTRACT(DAY FROM rfl.dt)
          <= p.max_day_of_month
),

/* ============================================================
   Целевые события после Предзаявки
   ============================================================ */
target_events AS (
    SELECT
        rfl.id AS event_id,
        rfl.dt AS target_event_dt,
        rfl.dt::date AS event_date,
        rfl.counterparty_id,
        rfl.kind_of_operation,
        op.operation_family,
        op.operation_group,

        rfl.kind_of_loan_id,
        rfl.contract_counterparty_id,
        rfl.step_id,
        rfl.reason_for_refusal_in_loan_id,
        rfril.name AS refusal_reason,
        rfl.comment_reject_reason,

        kol.available_ip,
        kol.available_self_employed,

        CASE
            WHEN dd.tribe IN (
                'Трайб ВД',
                'Трайб Онлайн'
            )
                THEN 'Трайб ВД'
            ELSE 'Розница'
        END AS tribe,

        dd.squad,
        dd.division,

        COALESCE(
            dsc.channel_name,
            'Не определено'
        ) AS sales_channel,

        CASE
            WHEN dsc.channel_name IN (
                'Безналично в офисе',
                'Наличными в офисе'
            )
                THEN 'Офис'

            WHEN dsc.channel_name IN (
                'В личном кабинете',
                'Рефинансирование в ЛК',
                'В личном кабинете - Стейдж'
            )
                THEN 'ЛК'

            WHEN dsc.channel_name IN (
                'mobileapp-android-flutter',
                'mobileapp-ios-flutter',
                'Мобильное приложение',
                'Мобильное приложение (Android)',
                'Мобильное приложение (IOS)'
            )
                THEN 'Моб. приложение'

            ELSE COALESCE(
                dsc.channel_name,
                'Не определено'
            )
        END AS channel,

        CASE
            WHEN rfl.is_new_counterparty IS TRUE
                THEN 'Новый клиент'
            ELSE 'Повторный клиент'
        END AS client_type

    FROM public.request_for_loan rfl

    CROSS JOIN params p

    JOIN target_operations op
        ON op.operation_name =
           rfl.kind_of_operation

    LEFT JOIN public.reasons_for_refusal_in_loan rfril
        ON rfril.id =
           rfl.reason_for_refusal_in_loan_id

    LEFT JOIN public.kind_of_loans kol
        ON kol.id = rfl.kind_of_loan_id

    LEFT JOIN dash.dict_division dd
        ON dd.division_id = rfl.subdivision_id

    LEFT JOIN dash.dict_sales_channel dsc
        ON dsc.channel_id = rfl.chanel_sales_id

    WHERE rfl.marker_delete IS FALSE
      AND rfl.counterparty_id IS NOT NULL
      AND rfl.dt >= p.date_from
      AND rfl.dt < p.date_to
      AND EXTRACT(DAY FROM rfl.dt)
          <= p.max_day_of_month
),

product_applications AS (
    SELECT *
    FROM target_events
    WHERE operation_group = 'PRODUCT'
),

/* ============================================================
   Клиентские дни
   ============================================================ */
preapplication_days AS (
    SELECT
        event_date,
        counterparty_id,
        COUNT(*) AS preapplication_count,
        MIN(preapplication_dt)
            AS first_preapplication_dt,
        MAX(preapplication_dt)
            AS last_preapplication_dt

    FROM preapplications

    GROUP BY
        event_date,
        counterparty_id
),

product_days AS (
    SELECT
        event_date,
        counterparty_id,
        COUNT(*) AS product_application_count,
        MIN(target_event_dt)
            AS first_product_application_dt,
        MAX(target_event_dt)
            AS last_product_application_dt

    FROM product_applications

    GROUP BY
        event_date,
        counterparty_id
),

client_days AS (
    SELECT
        COALESCE(
            pr.event_date,
            pa.event_date
        ) AS event_date,

        COALESCE(
            pr.counterparty_id,
            pa.counterparty_id
        ) AS counterparty_id,

        COALESCE(
            pr.preapplication_count,
            0
        ) AS preapplication_count,

        pr.first_preapplication_dt,
        pr.last_preapplication_dt,

        COALESCE(
            pa.product_application_count,
            0
        ) AS product_application_count,

        pa.first_product_application_dt,
        pa.last_product_application_dt

    FROM preapplication_days pr

    FULL JOIN product_days pa
        ON pa.event_date = pr.event_date
       AND pa.counterparty_id =
           pr.counterparty_id
),
client_profile AS (
    SELECT
        cp.id AS counterparty_id,
        cp.date_of_birth,
        cp.position AS client_position,
        catp.name AS position_category,
        cp.gender AS client_gender,
        cp.education AS client_education,
        cp.family_status AS client_marital_status,

        address.city AS residence_city,
        address.region AS residence_region

    FROM (
        SELECT DISTINCT counterparty_id
        FROM client_days
    ) needed_clients

    JOIN public.counterparties cp
        ON cp.id = needed_clients.counterparty_id

    LEFT JOIN public.categories_posts catp
        ON catp.id = cp.category_posts_id

    LEFT JOIN LATERAL (
        SELECT            
            COALESCE(
                NULLIF(BTRIM(cci.city), ''),
                NULLIF(
                    BTRIM(
                        (
                            regexp_match(
                                cci.fild_values,
                                '<НаселПункт>([^<]*)</НаселПункт>'
                            )
                        )[1]
                    ),
                    ''
                )
            ) AS city,

            COALESCE(
                NULLIF(BTRIM(cci.region), ''),
                NULLIF(
                    BTRIM(
                        (
                            regexp_match(
                                cci.fild_values,
                                '<СубъектРФ>([^<]*)</СубъектРФ>'
                            )
                        )[1]
                    ),
                    ''
                )
            ) AS region

        FROM public.counterparties_contact_information cci

        LEFT JOIN public.kind_of_contact_information kind
            ON kind.id = cci.kind_id

        LEFT JOIN public.kind_of_contact_information kind_for_list
            ON kind_for_list.id = cci.kind_for_list_id

        WHERE cci.id = cp.id
          AND (
              kind.name_of_predefined_data IN (
                  'ФактАдресКонтрагента',
                  'ЮрАдресКонтрагента'
              )
              OR kind_for_list.name_of_predefined_data IN (
                  'ФактАдресКонтрагента',
                  'ЮрАдресКонтрагента'
              )
          )

        ORDER BY
            CASE
                WHEN kind.name_of_predefined_data =
                         'ФактАдресКонтрагента'
                  OR kind_for_list.name_of_predefined_data =
                         'ФактАдресКонтрагента'
                    THEN 0
                ELSE 1
            END,

            COALESCE(
                cci.valid_from::timestamp,
                cci.dt_change
            ) DESC NULLS LAST,

            cci.dt_change DESC NULLS LAST,
            cci.number_rows DESC

        LIMIT 1
    ) address ON TRUE
),
/* ============================================================
   Якорная Предзаявка:
   последняя до первой продуктовой заявки;
   если заявки нет — последняя Предзаявка дня
   ============================================================ */
anchor_preapplication AS (
    SELECT
        cd.*,

        anchor.preapplication_id,
        anchor.preapplication_dt,
        anchor.client_code,
        anchor.preapplication_number,
        anchor.amount_requested,

        anchor.channel,
        anchor.sales_channel,
        anchor.tribe,
        anchor.squad,
        anchor.division,
        anchor.client_type,

        anchor.preapplication_finished,
        anchor.preapplication_success,
        anchor.preapplication_refused,
        anchor.preapplication_result,

        anchor.preapplication_success_step,
        anchor.preapplication_refusal_step,
        anchor.preapplication_have_refusal_reason,

        anchor.preapplication_refusal_reason,
        anchor.comment_reject_reason,

        anchor.anomaly_success_step_with_refusal_reason

    FROM client_days cd

    LEFT JOIN LATERAL (
        SELECT p.*

        FROM preapplications p

        WHERE p.event_date = cd.event_date
          AND p.counterparty_id =
              cd.counterparty_id
        ORDER by
        CASE
            WHEN cd.first_product_application_dt IS NULL
                THEN 0
            WHEN p.preapplication_dt <= cd.first_product_application_dt
                THEN 0
            ELSE 1
        END,
            p.preapplication_dt DESC,
            p.preapplication_id DESC

        LIMIT 1
    ) anchor ON TRUE
),

/* ============================================================
   Запуски МПР
   ============================================================ */
mpr_requests AS (
    SELECT DISTINCT
        msi.loan_request_id,
        msi.request_id,
        msi.request_dtm

    FROM tb.reg_mpr_service_ids msi

    WHERE COALESCE(msi.is_deleted, 0) = 0
),

latest_mpr_request AS (
    SELECT
        loan_request_id,
        request_id,
        request_dtm

    FROM (
        SELECT
            mr.*,

            ROW_NUMBER() OVER (
                PARTITION BY mr.loan_request_id
                ORDER BY
                    mr.request_dtm DESC NULLS LAST,
                    mr.request_id DESC
            ) AS rn

        FROM mpr_requests mr
    ) ranked

    WHERE rn = 1
),

/* ============================================================
   Скоринг, ПДН и налоговые статусы
   ============================================================ */
mpr_client_features AS (
    SELECT
        lmr.loan_request_id
            AS preapplication_id,

        lmr.request_id
            AS last_mpr_request_id,

        lmr.request_dtm
            AS last_mpr_request_dtm,

        scoring.score_value,

        client_data.mpr_pdn,
        client_data.mpr_income,
        client_data.mpr_smp1,

        tax_info.tax_info_found,
        tax_info.have_inn_problem,
        tax_info.ip_status,
        tax_info.self_employed_status

    FROM latest_mpr_request lmr

    LEFT JOIN LATERAL (
        SELECT
            MAX(rbs.score_value)
                AS score_value

        FROM select_solution_for_client.req_bki_scoring rbs

        WHERE rbs.loan_request_id =
              lmr.loan_request_id
    ) scoring ON TRUE

    LEFT JOIN LATERAL (
        SELECT
            MAX(rcd.pdn)
                AS mpr_pdn,

            MAX(rcd.income)
                AS mpr_income,

            MAX(rcd.smp1)
                AS mpr_smp1

        FROM select_solution_for_client.req_client_data rcd

        WHERE rcd.loan_request_id =
              lmr.loan_request_id
    ) client_data ON TRUE

    LEFT JOIN LATERAL (
        SELECT
            COUNT(*) > 0
                AS tax_info_found,

            BOOL_OR(
                COALESCE(rni.invalid, FALSE)
            ) AS have_inn_problem,

            BOOL_OR(
                COALESCE(rni.ip_status, FALSE)
            ) AS ip_status,

            BOOL_OR(
                COALESCE(
                    rni.self_employed_status,
                    FALSE
                )
            ) AS self_employed_status

        FROM select_solution_for_client.req_nalog_info rni

        WHERE rni.loan_request_id =
              lmr.loan_request_id
    ) tax_info ON TRUE
),

/* ============================================================
   ПДН из расчёта 1С
   ============================================================ */
preapplication_pdn AS (
    SELECT
        pa.preapplication_id,

        pdn.pdn_amount
            AS calculated_pdn,

        pdn.average_monthly_income_amount
            AS calculated_pdn_income,

        pdn.average_monthly_credit_payment_amount
            AS calculated_smp1,

        pdn.nbki_average_monthly_payment_amount
            AS calculated_smp2

    FROM preapplications pa

    LEFT JOIN LATERAL (
        SELECT
            pn.pdn_amount,
            pn.average_monthly_income_amount,
            pn.average_monthly_credit_payment_amount,
            pn.nbki_average_monthly_payment_amount

        FROM public.pdn_nbki pn

        WHERE pn.request_for_laon_id =
              pa.preapplication_id

          AND pn.marker_delete IS FALSE
          AND pn.conducted IS TRUE
          AND pn.operation_kind = 'ВыдачаЗайма'

        ORDER BY
            pn.pdn_amount IS NOT NULL DESC

        LIMIT 1
    ) pdn ON TRUE
),

/* ============================================================
   Проверка ПСК
   ============================================================ */
preapplication_psk AS (
    SELECT
        pa.preapplication_id,
        psk.over_limit_loans_cnt,

        CASE
            WHEN psk.over_limit_loans_cnt IS NULL
                THEN NULL
            ELSE psk.over_limit_loans_cnt < 2
        END AS psk_passed

    FROM preapplications pa

    LEFT JOIN LATERAL (
        SELECT
            rplc.over_limit_loans_cnt

        FROM tb.reg_psk_limit_check rplc

        WHERE rplc.loan_request_id =
              pa.preapplication_id

          AND COALESCE(rplc.is_deleted, 0) = 0

        ORDER BY
            rplc.period_dtm DESC

        LIMIT 1
    ) psk ON TRUE
),

/* ============================================================
   Подобранные решения
   ============================================================ */
offers AS (
    SELECT DISTINCT
        ap.event_date,
        ap.counterparty_id,
        ap.preapplication_id,

        sm.solution_code,
        sm.solution_name,
        sm.solution_family,
        sm.solution_group,

        rss.request_dtm
            AS solution_request_dtm,

        rss.solution_dt

    FROM anchor_preapplication ap

    JOIN tb.reg_selected_solutions rss
        ON rss.customer_id =
           ap.counterparty_id

       AND rss.solution_dt =
           ap.event_date

       AND COALESCE(rss.is_deleted, 0) = 0

    JOIN solution_map sm
        ON sm.solution_id =
           rss.solution_id

    WHERE ap.preapplication_id IS NOT NULL
),

offer_flags_base AS (
    SELECT
        ap.event_date,
        ap.counterparty_id,
        ap.preapplication_id,

        EXISTS (
            SELECT 1

            FROM mpr_requests mr

            WHERE mr.loan_request_id =
                  ap.preapplication_id
        ) AS mpr_started,

        COUNT(o.solution_code)
            AS offered_solution_count,

        STRING_AGG(
            DISTINCT o.solution_name,
            ', '
            ORDER BY o.solution_name
        ) AS offered_solutions,

        COALESCE(
            BOOL_OR(
                o.solution_group = 'PRODUCT'
            ),
            FALSE
        ) AS have_product_solution,

        COALESCE(
            BOOL_OR(
                o.solution_group = 'INTERMEDIATE'
            ),
            FALSE
        ) AS have_intermediate_solution,

        COALESCE(
            BOOL_OR(
                o.solution_group = 'CONSULTING'
            ),
            FALSE
        ) AS have_consulting_solution,

        COUNT(DISTINCT o.solution_code)
            FILTER (
                WHERE o.solution_family =
                      'CREDIT_LINE'
            ) AS offered_credit_line_count,

        MAX(o.solution_code)
            FILTER (
                WHERE o.solution_family =
                      'CREDIT_LINE'
            ) AS single_credit_line_code,

        MAX(o.solution_name)
            FILTER (
                WHERE o.solution_family =
                      'CREDIT_LINE'
            ) AS single_credit_line_name,
        COUNT(DISTINCT o.solution_code)
            FILTER (
                WHERE o.solution_family = 'AUTOZAIM'
            ) AS offered_autozaim_count,

        MAX(o.solution_code)
            FILTER (
                WHERE o.solution_family = 'AUTOZAIM'
            ) AS single_autozaim_code,

        MAX(o.solution_name)
            FILTER (
                WHERE o.solution_family = 'AUTOZAIM'
            ) AS single_autozaim_name

    FROM anchor_preapplication ap

    LEFT JOIN offers o
        ON o.event_date = ap.event_date
       AND o.counterparty_id =
           ap.counterparty_id
       AND o.preapplication_id =
           ap.preapplication_id

    GROUP BY
        ap.event_date,
        ap.counterparty_id,
        ap.preapplication_id
),

offer_flags AS (
    SELECT
        b.*,

        CASE
            WHEN NOT b.mpr_started
                THEN 'МПР не запускался'

            WHEN b.have_product_solution
                THEN 'Кредитное решение'

            WHEN b.have_intermediate_solution
             AND b.have_consulting_solution
                THEN
                    'Промежуточный сценарий + банкротство'

            WHEN b.have_intermediate_solution
                THEN
                    'Только промежуточный сценарий'

            WHEN b.have_consulting_solution
                THEN
                    'Только банкротство'

            WHEN b.offered_solution_count = 0
                THEN 'Нет решений'

            ELSE 'Другой результат'
        END AS mpr_result_group

    FROM offer_flags_base b
),

/* ============================================================
   Первое целевое событие после якорной Предзаявки
   ============================================================ */
first_target_after_preapplication AS (
    SELECT
        ap.event_date,
        ap.counterparty_id,
        ap.preapplication_id,
        ap.preapplication_dt,

        next_event.event_id,
        next_event.target_event_dt,
        next_event.kind_of_operation,
        next_event.operation_family,
        next_event.operation_group,
        next_event.kind_of_loan_id,
        next_event.available_ip,
        next_event.available_self_employed

    FROM anchor_preapplication ap

    LEFT JOIN LATERAL (
        SELECT te.*

        FROM target_events te

        WHERE te.event_date = ap.event_date
          AND te.counterparty_id =
              ap.counterparty_id
          AND te.target_event_dt >
              ap.preapplication_dt

        ORDER BY
            te.target_event_dt,
            te.event_id

        LIMIT 1
    ) next_event ON TRUE

    WHERE ap.preapplication_id IS NOT NULL
),

/* ============================================================
   Точное соответствие первого события решению
   ============================================================ */
exact_selected_rows AS (
    SELECT
        f.event_date,
        f.counterparty_id,
        f.preapplication_id,

        o.solution_code,
        o.solution_name,
        o.solution_family,
        o.solution_group

    FROM first_target_after_preapplication f

    JOIN offers o
        ON o.event_date = f.event_date
       AND o.counterparty_id =
           f.counterparty_id
       AND o.preapplication_id =
           f.preapplication_id

    WHERE
        (
            o.solution_code = 'INCOME_CERT'
            AND f.kind_of_operation =
                'ПодтверждениеДохода'
        )

        OR
        (
            o.solution_code = 'REFINANCING'
            AND f.operation_family =
                'REFINANCING'
        )

        OR
        (
            o.solution_code = 'SELF_EMPLOYED'
            AND f.operation_family =
                'CREDIT_LINE'
            AND f.available_self_employed IS TRUE
        )

        OR
        (
            o.solution_code =
                'INDIVIDUAL_ENTREPRENEUR'
            AND f.operation_family =
                'CREDIT_LINE'
            AND f.available_ip IS TRUE
        )

        OR
        (
            o.solution_code IN (
                'CREDIT_LINE',
                'CREDIT_LINE_REDUCED_LIMIT',
                'CREDIT_LINE_PSK_LIMIT_REDUCTION'
            )
            AND f.operation_family =
                'CREDIT_LINE'
            AND f.available_ip IS FALSE
            AND f.available_self_employed IS FALSE
        )

        OR
        (
            o.solution_code =
                'LOAN_REDUCTION'
            AND f.kind_of_operation IN (
                'ВыдачаОнлайн',
                'Долгосрочный'
            )
        )

        OR
        (
            o.solution_code =
                'CONSUMER_LOAN'
            AND f.kind_of_operation IN (
                'Долгосрочный',
                'ЗаключениеДоговораЗайма'
            )
        )

        OR
        (
            o.solution_code = 'AUTOZAIM'
            AND f.operation_family =
                'AUTOZAIM'
            AND f.available_ip IS FALSE
            AND f.available_self_employed IS FALSE
        )

        OR
        (
            o.solution_code = 'AUTOZAIM_IP'
            AND f.operation_family =
                'AUTOZAIM'
            AND f.available_ip IS TRUE
        )

        OR
        (
            o.solution_code =
                'AUTOZAIM_SELF_EMPLOYED'
            AND f.operation_family =
                'AUTOZAIM'
            AND f.available_self_employed IS TRUE
        )
),

exact_selection_agg AS (
    SELECT
        f.event_date,
        f.counterparty_id,
        f.preapplication_id,

        COUNT(esr.solution_code)
            AS exact_match_count,

        STRING_AGG(
            DISTINCT esr.solution_code,
            ', '
            ORDER BY esr.solution_code
        ) AS exact_solution_codes,

        STRING_AGG(
            DISTINCT esr.solution_name,
            ', '
            ORDER BY esr.solution_name
        ) AS exact_solution_names,

        COALESCE(
            BOOL_OR(
                esr.solution_group = 'PRODUCT'
            ),
            FALSE
        ) AS exact_product_selected,

        COALESCE(
            BOOL_OR(
                esr.solution_group = 'INTERMEDIATE'
            ),
            FALSE
        ) AS exact_intermediate_selected,

        MAX(esr.solution_family)
            AS exact_solution_family

    FROM first_target_after_preapplication f

    LEFT JOIN exact_selected_rows esr
        ON esr.event_date = f.event_date
       AND esr.counterparty_id =
           f.counterparty_id
       AND esr.preapplication_id =
           f.preapplication_id

    GROUP BY
        f.event_date,
        f.counterparty_id,
        f.preapplication_id
),

/* ============================================================
   Итог выбора решения

   Для кредитной линии:
   1. точное совпадение по виду займа;
   2. одно предложение КЛ — определяем по нему;
   3. несколько предложений КЛ, вид займа пуст —
      считаем выбор продукта, но конкретное решение неоднозначно.
   ============================================================ */
selection AS (
    SELECT
        f.event_date,
        f.counterparty_id,
        f.preapplication_id,

        f.event_id
            AS first_target_event_id,

        f.target_event_dt
            AS first_target_event_dt,

        f.kind_of_operation
            AS first_target_operation,

        f.operation_family
            AS first_target_family,

        f.operation_group
            AS first_target_group,

        CASE
    WHEN esa.exact_match_count > 0
        THEN esa.exact_solution_codes

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count = 1
        THEN ofl.single_credit_line_code

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count > 1
        THEN 'CREDIT_LINE_AMBIGUOUS'

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count = 1
        THEN ofl.single_autozaim_code

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count > 1
        THEN 'AUTOZAIM_AMBIGUOUS'

    ELSE NULL
END AS selected_solution_codes,

        CASE
    WHEN esa.exact_match_count > 0
        THEN esa.exact_solution_names

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count = 1
        THEN ofl.single_credit_line_name

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count > 1
        THEN 'Кредитная линия — конкретное решение не определено'

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count = 1
        THEN ofl.single_autozaim_name

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count > 1
        THEN 'Автозайм — конкретное решение не определено'

    ELSE NULL
END AS selected_solution_names,

        CASE
    WHEN esa.exact_match_count > 0
        THEN esa.exact_solution_family

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count > 0
        THEN 'CREDIT_LINE'

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count > 0
        THEN 'AUTOZAIM'

    ELSE NULL
END AS selected_solution_family,
        CASE
    WHEN esa.exact_match_count > 0
        THEN 'Точное соответствие по виду займа'

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count = 1
        THEN 'Определено по единственному предложению КЛ'

    WHEN f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count > 1
        THEN 'Несколько предложений КЛ — конкретный тип не определён'

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count = 1
        THEN 'Определено по единственному предложению автозайма'

    WHEN f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count > 1
        THEN 'Несколько предложений автозайма — конкретный тип не определён'

    ELSE 'Решение не выбрано'
END AS selection_method,

        CASE
    WHEN esa.exact_product_selected
        THEN TRUE

    WHEN f.operation_group = 'PRODUCT'
     AND f.operation_family = 'CREDIT_LINE'
     AND ofl.offered_credit_line_count > 0
        THEN TRUE

    WHEN f.operation_group = 'PRODUCT'
     AND f.operation_family = 'AUTOZAIM'
     AND ofl.offered_autozaim_count > 0
        THEN TRUE

    ELSE FALSE
END AS product_solution_selected,

        esa.exact_intermediate_selected
            AS intermediate_solution_selected,

(
    (
        f.operation_family = 'CREDIT_LINE'
        AND esa.exact_match_count = 0
        AND ofl.offered_credit_line_count > 1
    )
    OR
    (
        f.operation_family = 'AUTOZAIM'
        AND esa.exact_match_count = 0
        AND ofl.offered_autozaim_count > 1
    )
) AS selection_ambiguous

    FROM first_target_after_preapplication f

    LEFT JOIN exact_selection_agg esa
        ON esa.event_date = f.event_date
       AND esa.counterparty_id =
           f.counterparty_id
       AND esa.preapplication_id =
           f.preapplication_id

    LEFT JOIN offer_flags ofl
        ON ofl.event_date = f.event_date
       AND ofl.counterparty_id =
           f.counterparty_id
       AND ofl.preapplication_id =
           f.preapplication_id
),

/* ============================================================
   Результат каждой продуктовой заявки:
   договор и выдача в D0–D3
   ============================================================ */
application_outcomes AS (
    SELECT
        pa.*,

        pa.refusal_reason
            AS application_refusal_reason,

        coc.id AS contract_id,
        coc.code AS contract_code,
        coc.dt AS contract_dt,

        coc.marker_delete
            AS contract_marker_delete,

        coc.loan_amount
            AS contract_amount,

        (
            coc.id IS NOT NULL
            AND coc.dt = pa.event_date
        ) AS contract_same_day,

        issue.first_issue_dt,
        issue.first_issue_amount,
        issue.issue_amount_3d,

        COALESCE(
            issue.issue_count_3d,
            0
        ) AS issue_count_3d,

        COALESCE(
            issue.have_tranche_flag,
            FALSE
        ) AS have_tranche_flag,

        COALESCE(
            issue.have_prolong_flag,
            FALSE
        ) AS have_prolong_flag,

        COALESCE(
            issue.have_renewal_flag,
            FALSE
        ) AS have_renewal_flag,

        COALESCE(
            issue.have_refinance_flag,
            FALSE
        ) AS have_refinance_flag,

        issue.first_issue_dt IS NOT NULL
            AS have_issue_3d,

        CASE
            WHEN pa.operation_family =
                 'CREDIT_LINE'
             AND issue.first_issue_dt IS NOT NULL
                THEN TRUE
            ELSE FALSE
        END AS have_first_tranche_3d,

        CASE
            WHEN pa.operation_family <>
                 'CREDIT_LINE'
             AND issue.first_issue_dt IS NOT NULL
                THEN TRUE
            ELSE FALSE
        END AS have_regular_issue_3d,

        CASE
            WHEN coc.id IS NULL
                THEN FALSE

            ELSE p.as_of_date > coc.dt + 3
        END AS result_mature,

        CASE
            WHEN coc.id IS NULL
                THEN 'Заявка без договора'

            WHEN coc.dt <> pa.event_date
                THEN
                    'Договор не относится к текущему дню'

            WHEN issue.first_issue_dt IS NOT NULL
             AND COALESCE(
                 coc.marker_delete,
                 FALSE
             )
                THEN
                    'Деньги выданы — договор помечен на удаление'

            WHEN issue.first_issue_dt IS NOT NULL
             AND pa.operation_family =
                 'CREDIT_LINE'
                THEN 'Первый транш выдан'

            WHEN issue.first_issue_dt IS NOT NULL
                THEN 'Деньги выданы'

            WHEN p.as_of_date <= coc.dt + 3
                THEN
                    'Ожидается результат выдачи'

            WHEN COALESCE(
                coc.marker_delete,
                FALSE
            )
                THEN 'Договор аннулирован'

            ELSE 'Договор без выдачи'
        END AS application_final_result

    FROM product_applications pa

    CROSS JOIN params p

    LEFT JOIN public.contracts_of_counterparties coc
        ON coc.id =
           pa.contract_counterparty_id

    LEFT JOIN LATERAL (
        SELECT
            MIN(di.issue_dt)
                AS first_issue_dt,

            (
                ARRAY_AGG(
                    di.issue_amt
                    ORDER BY
                        di.issue_dt,
                        di.tranche_number,
                        di.prolong_number
                )
            )[1] AS first_issue_amount,

            SUM(di.issue_amt)
                AS issue_amount_3d,

            COUNT(*)
                AS issue_count_3d,

            BOOL_OR(
                COALESCE(
                    di.is_tranche,
                    FALSE
                )
            ) AS have_tranche_flag,

            BOOL_OR(
                COALESCE(
                    di.is_prolong,
                    FALSE
                )
            ) AS have_prolong_flag,

            BOOL_OR(
                COALESCE(
                    di.is_renewal,
                    FALSE
                )
            ) AS have_renewal_flag,

            BOOL_OR(
                COALESCE(
                    di.is_refinance,
                    FALSE
                )
            ) AS have_refinance_flag

        FROM dash.data_issue di

        WHERE di.contract_id = coc.id
          AND di.issue_dt
              BETWEEN coc.dt AND coc.dt + 3
          AND COALESCE(di.issue_amt, 0) > 0
    ) issue ON TRUE
),

/* ============================================================
   Все заявки семейства первого выбранного решения
   ============================================================ */
selected_attempt_candidates AS (
    SELECT
        sel.event_date,
        sel.counterparty_id,
        sel.preapplication_id,

        ao.event_id AS application_id,
        ao.target_event_dt AS application_dt,
        ao.kind_of_operation,
        ao.operation_family,
        ao.application_refusal_reason,

        ao.contract_id,
        ao.contract_code,
        ao.contract_dt,
        ao.contract_marker_delete,
        ao.contract_amount,

        ao.first_issue_dt,
        ao.first_issue_amount,
        ao.issue_amount_3d,
        ao.issue_count_3d,

        ao.have_tranche_flag,
        ao.have_prolong_flag,
        ao.have_renewal_flag,
        ao.have_refinance_flag,

        ao.have_first_tranche_3d,
        ao.have_regular_issue_3d,
        ao.have_issue_3d,
        ao.result_mature,
        ao.application_final_result

    FROM selection sel

    JOIN application_outcomes ao
        ON ao.event_date = sel.event_date
       AND ao.counterparty_id =
           sel.counterparty_id
       AND ao.target_event_dt >=
           sel.first_target_event_dt

    WHERE sel.product_solution_selected
      AND (
          ao.operation_family =
          sel.selected_solution_family

          OR (
              sel.selected_solution_family =
                  'CONSUMER_LOAN'

              AND ao.kind_of_operation IN (
                  'Долгосрочный',
                  'ЗаключениеДоговораЗайма'
              )
          )

          OR (
              sel.selected_solution_family =
                  'LOAN_REDUCTION'

              AND ao.kind_of_operation IN (
                  'ВыдачаОнлайн',
                  'Долгосрочный'
              )
          )
      )
),

best_selected_attempt AS (
    SELECT *

    FROM (
        SELECT
            sac.*,

            ROW_NUMBER() OVER (
                PARTITION BY
                    sac.event_date,
                    sac.counterparty_id,
                    sac.preapplication_id

                ORDER BY
                    sac.have_issue_3d DESC,
                    (
                        sac.contract_id IS NOT NULL
                    ) DESC,
                    sac.application_dt DESC,
                    sac.application_id DESC
            ) AS rn

        FROM selected_attempt_candidates sac
    ) ranked

    WHERE rn = 1
),

/* ============================================================
   Лучший общий результат клиента:
   выдача → договор → последняя заявка
   ============================================================ */
best_client_attempt AS (
    SELECT *

    FROM (
        SELECT
            ao.*,

            ROW_NUMBER() OVER (
                PARTITION BY
                    ao.event_date,
                    ao.counterparty_id

                ORDER BY
                    ao.have_issue_3d DESC,
                    ao.contract_same_day DESC,
                    ao.target_event_dt DESC,
                    ao.event_id DESC
            ) AS rn

        FROM application_outcomes ao
    ) ranked

    WHERE rn = 1
),

/* ============================================================
   Точные совпадения итоговой заявки с предложениями МПР.

   Для КЛ:
   - available_ip = true → КЛ для ИП;
   - available_self_employed = true → КЛ для самозанятого;
   - оба false → одно из решений КЛ для ФЛ;
   - NULL → точный тип решения пока определить нельзя.
   ============================================================ */
best_application_exact_offer_rows AS (
    SELECT DISTINCT
        bca.event_date,
        bca.counterparty_id,

        o.solution_code,
        o.solution_name,
        o.solution_family

    FROM best_client_attempt bca

    JOIN anchor_preapplication ap
        ON ap.event_date = bca.event_date
       AND ap.counterparty_id = bca.counterparty_id

    JOIN offers o
        ON o.event_date = bca.event_date
       AND o.counterparty_id = bca.counterparty_id
       AND o.preapplication_id = ap.preapplication_id
       AND o.solution_group = 'PRODUCT'

    WHERE
        /* Рефинансирование. */
        (
            o.solution_code = 'REFINANCING'
            AND bca.operation_family = 'REFINANCING'
        )

        /* Кредитная линия для самозанятого. */
        OR (
            o.solution_code = 'SELF_EMPLOYED'
            AND bca.operation_family = 'CREDIT_LINE'
            AND bca.available_self_employed IS TRUE
        )

        /* Кредитная линия для ИП. */
        OR (
            o.solution_code = 'INDIVIDUAL_ENTREPRENEUR'
            AND bca.operation_family = 'CREDIT_LINE'
            AND bca.available_ip IS TRUE
        )

        /* Кредитная линия для физического лица. */
        OR (
            o.solution_code IN (
                'CREDIT_LINE',
                'CREDIT_LINE_REDUCED_LIMIT',
                'CREDIT_LINE_PSK_LIMIT_REDUCTION'
            )
            AND bca.operation_family = 'CREDIT_LINE'
            AND bca.available_ip IS FALSE
            AND bca.available_self_employed IS FALSE
        )

        /* Снижение суммы займа. */
        OR (
            o.solution_code = 'LOAN_REDUCTION'
            AND bca.kind_of_operation IN (
                'ВыдачаОнлайн',
                'Долгосрочный'
            )
        )

        /* Потребительский заём. */
        OR (
            o.solution_code = 'CONSUMER_LOAN'
            AND bca.kind_of_operation IN (
                'Долгосрочный',
                'ЗаключениеДоговораЗайма'
            )
        )

        /* Обычный автозайм. */
        OR (
            o.solution_code = 'AUTOZAIM'
            AND bca.operation_family = 'AUTOZAIM'
            AND bca.available_ip IS FALSE
            AND bca.available_self_employed IS FALSE
        )

        /* Автозайм для ИП. */
        OR (
            o.solution_code = 'AUTOZAIM_IP'
            AND bca.operation_family = 'AUTOZAIM'
            AND bca.available_ip IS TRUE
        )

        /* Автозайм для самозанятого. */
        OR (
            o.solution_code = 'AUTOZAIM_SELF_EMPLOYED'
            AND bca.operation_family = 'AUTOZAIM'
            AND bca.available_self_employed IS TRUE
        )
),

/* ============================================================
   Агрегация совпадений итоговой заявки.

   Для КЛ и автозайма дополнительно считаем число предложений
   соответствующего семейства — это нужно, когда вид займа
   в заявке ещё не заполнен.
   ============================================================ */
best_application_offer_match_base AS (
    SELECT
        bca.event_date,
        bca.counterparty_id,

        bca.operation_family
            AS final_application_family,

        COUNT(DISTINCT exact.solution_code)
            AS exact_offer_match_count,

        STRING_AGG(
            DISTINCT exact.solution_name,
            ', ' ORDER BY exact.solution_name
        ) AS exact_matched_offered_solutions,

        COUNT(DISTINCT o.solution_code)
            FILTER (
                WHERE o.solution_family = 'CREDIT_LINE'
            ) AS offered_credit_line_count,

        MAX(o.solution_code)
            FILTER (
                WHERE o.solution_family = 'CREDIT_LINE'
            ) AS single_credit_line_code,

        MAX(o.solution_name)
            FILTER (
                WHERE o.solution_family = 'CREDIT_LINE'
            ) AS single_credit_line_name,

        COUNT(DISTINCT o.solution_code)
            FILTER (
                WHERE o.solution_family = 'AUTOZAIM'
            ) AS offered_autozaim_count,

        MAX(o.solution_code)
            FILTER (
                WHERE o.solution_family = 'AUTOZAIM'
            ) AS single_autozaim_code,

        MAX(o.solution_name)
            FILTER (
                WHERE o.solution_family = 'AUTOZAIM'
            ) AS single_autozaim_name

    FROM best_client_attempt bca

    LEFT JOIN anchor_preapplication ap
        ON ap.event_date = bca.event_date
       AND ap.counterparty_id = bca.counterparty_id

    LEFT JOIN offers o
        ON o.event_date = bca.event_date
       AND o.counterparty_id = bca.counterparty_id
       AND o.preapplication_id = ap.preapplication_id
       AND o.solution_group = 'PRODUCT'

    LEFT JOIN best_application_exact_offer_rows exact
        ON exact.event_date = bca.event_date
       AND exact.counterparty_id = bca.counterparty_id

    GROUP BY
        bca.event_date,
        bca.counterparty_id,
        bca.operation_family
),

/* ============================================================
   Итоговое сопоставление заявки с предложением МПР.

   Приоритет:
   1. точное соответствие по виду займа;
   2. единственное предложение семейства;
   3. несколько предложений — семейство совпало,
      но конкретное решение не определено.
   ============================================================ */
best_application_offer_match AS (
    SELECT
        b.*,

        CASE
            WHEN b.exact_offer_match_count > 0
                THEN b.exact_matched_offered_solutions

            WHEN b.final_application_family = 'CREDIT_LINE'
             AND b.offered_credit_line_count = 1
                THEN b.single_credit_line_name

            WHEN b.final_application_family = 'CREDIT_LINE'
             AND b.offered_credit_line_count > 1
                THEN
                    'Кредитная линия — конкретное решение не определено'

            WHEN b.final_application_family = 'AUTOZAIM'
             AND b.offered_autozaim_count = 1
                THEN b.single_autozaim_name

            WHEN b.final_application_family = 'AUTOZAIM'
             AND b.offered_autozaim_count > 1
                THEN
                    'Автозайм — конкретное решение не определено'

            ELSE NULL
        END AS final_matched_offered_solutions,

        CASE
            WHEN b.exact_offer_match_count > 0
                THEN 'Точное соответствие по виду займа'

            WHEN b.final_application_family = 'CREDIT_LINE'
             AND b.offered_credit_line_count = 1
                THEN
                    'Определено по единственному предложению КЛ'

            WHEN b.final_application_family = 'CREDIT_LINE'
             AND b.offered_credit_line_count > 1
                THEN
                    'Несколько предложений КЛ — конкретный тип не определён'

            WHEN b.final_application_family = 'AUTOZAIM'
             AND b.offered_autozaim_count = 1
                THEN
                    'Определено по единственному предложению автозайма'

            WHEN b.final_application_family = 'AUTOZAIM'
             AND b.offered_autozaim_count > 1
                THEN
                    'Несколько предложений автозайма — конкретный тип не определён'

            ELSE 'Итоговая заявка не соответствует предложениям МПР'
        END AS final_offer_match_method,

        (
            b.exact_offer_match_count > 0

            OR (
                b.final_application_family = 'CREDIT_LINE'
                AND b.offered_credit_line_count > 0
            )

            OR (
                b.final_application_family = 'AUTOZAIM'
                AND b.offered_autozaim_count > 0
            )
        ) AS final_application_matches_any_offer,

        (
            (
                b.final_application_family = 'CREDIT_LINE'
                AND b.exact_offer_match_count = 0
                AND b.offered_credit_line_count > 1
            )
            OR
            (
                b.final_application_family = 'AUTOZAIM'
                AND b.exact_offer_match_count = 0
                AND b.offered_autozaim_count > 1
            )
        ) AS final_offer_match_ambiguous

    FROM best_application_offer_match_base b
),

/* ============================================================
   Итоговая Excel-витрина
   ============================================================ */
excel_data AS (
    SELECT
        cd.event_date,

        DATE_TRUNC(
            'month',
            cd.event_date
        )::date AS report_month,

        EXTRACT(
            DAY FROM cd.event_date
        )::integer AS day_of_month,

        cd.counterparty_id,
        ap.client_code,

        COALESCE(
            ap.tribe,
            bca.tribe,
            'Не определено'
        ) AS tribe,

        COALESCE(
            ap.squad,
            bca.squad
        ) AS squad,

        REGEXP_REPLACE(
    COALESCE(ap.division, bca.division),
    E'[\\r\\n\\t]+',
    ' ',
    'g'
) AS division,

        COALESCE(
            ap.channel,
            bca.channel,
            'Не определено'
        ) AS channel,

        COALESCE(
            ap.sales_channel,
            bca.sales_channel,
            'Не определено'
        ) AS sales_channel,

        COALESCE(
            ap.client_type,
            bca.client_type,
            'Не определено'
        ) AS client_type,
                /* Соцдем клиента */
        CASE
            WHEN cp.date_of_birth IS NULL
                THEN NULL
            ELSE EXTRACT(
                YEAR FROM age(cd.event_date, cp.date_of_birth)
            )::integer
        END AS client_age,

        CASE
            WHEN cp.date_of_birth IS NULL
                THEN NULL

            WHEN EXTRACT(
                YEAR FROM age(cd.event_date, cp.date_of_birth)
            )::integer < 18
                THEN NULL

            WHEN EXTRACT(
                YEAR FROM age(cd.event_date, cp.date_of_birth)
            )::integer <= 24
                THEN '18–24'

            ELSE CONCAT(
                (
                    25
                    + (
                        (
                            EXTRACT(
                                YEAR FROM age(
                                    cd.event_date,
                                    cp.date_of_birth
                                )
                            )::integer - 25
                        ) / 5
                    ) * 5
                )::text,
                '–',
                (
                    29
                    + (
                        (
                            EXTRACT(
                                YEAR FROM age(
                                    cd.event_date,
                                    cp.date_of_birth
                                )
                            )::integer - 25
                        ) / 5
                    ) * 5
                )::text
            )
        END AS client_age_group,

        cp.client_position,
        cp.position_category,
        cp.client_gender,
        cp.residence_city,
        cp.residence_region,
        cp.client_education,
        cp.client_marital_status,

        cd.preapplication_count,
        cd.product_application_count,

        CASE
            WHEN cd.preapplication_count > 1
             AND cd.product_application_count > 1
                THEN
                    'Несколько Предзаявок и продуктовых заявок'

            WHEN cd.preapplication_count > 1
                THEN 'Несколько Предзаявок'

            WHEN cd.product_application_count > 1
                THEN 'Несколько продуктовых заявок'

            ELSE 'Один процесс'
        END AS process_complexity,

        (
            cd.preapplication_count > 1
            OR cd.product_application_count > 1
        ) AS complex_client_day,

        /* Предзаявка */
        ap.preapplication_id
            AS anchor_preapplication_id,

        ap.preapplication_dt
            AS anchor_preapplication_dt,

        ap.preapplication_number,
        ap.amount_requested,

        COALESCE(
            ap.preapplication_finished,
            FALSE
        ) AS preapplication_finished,

        COALESCE(
            ap.preapplication_success,
            FALSE
        ) AS preapplication_success,

        COALESCE(
            ap.preapplication_refused,
            FALSE
        ) AS preapplication_refused,

        COALESCE(
            ap.preapplication_result,
            'Предзаявка отсутствует'
        ) AS preapplication_result,

        COALESCE(
            ap.preapplication_success_step,
            FALSE
        ) AS preapplication_success_step,

        COALESCE(
            ap.preapplication_refusal_step,
            FALSE
        ) AS preapplication_refusal_step,

        COALESCE(
            ap.preapplication_have_refusal_reason,
            FALSE
        ) AS preapplication_have_refusal_reason,

        COALESCE(
            ap.anomaly_success_step_with_refusal_reason,
            FALSE
        ) AS anomaly_success_step_with_refusal_reason,

        REGEXP_REPLACE(
    ap.preapplication_refusal_reason,
    E'[\\r\\n\\t]+',
    ' ',
    'g'
) AS preapplication_refusal_reason,
        REGEXP_REPLACE(
    ap.comment_reject_reason,
    E'[\\r\\n\\t]+',
    ' ',
    'g'
) AS comment_reject_reason,

        /* МПР */
        COALESCE(
            ofl.mpr_started,
            FALSE
        ) AS mpr_started,

        mcf.last_mpr_request_id,
        mcf.last_mpr_request_dtm,

        COALESCE(
            ofl.offered_solution_count,
            0
        ) AS offered_solution_count,

        ofl.offered_solutions,
        ofl.mpr_result_group,

        COALESCE(
            ofl.have_product_solution,
            FALSE
        ) AS have_product_solution,

        COALESCE(
            ofl.have_intermediate_solution,
            FALSE
        ) AS have_intermediate_solution,

        COALESCE(
            ofl.have_consulting_solution,
            FALSE
        ) AS have_consulting_solution,

        /* Скоринг */
        mcf.score_value AS scoring_score,

        CASE
            WHEN NOT COALESCE(
                ofl.mpr_started,
                FALSE
            )
                THEN 'МПР не запускался'

            WHEN mcf.score_value IS NULL
                THEN 'Нет скорингового балла'

            WHEN mcf.score_value <= 500
                THEN 'До 500'

            WHEN mcf.score_value <= 550
                THEN '501–550'

            WHEN mcf.score_value <= 600
                THEN '551–600'

            WHEN mcf.score_value <= 650
                THEN '601–650'

            WHEN mcf.score_value <= 700
                THEN '651–700'

            ELSE 'После 700'
        END AS scoring_score_group,

        /* Налоговый статус */
        CASE
            WHEN NOT COALESCE(
                ofl.mpr_started,
                FALSE
            )
                THEN NULL

            WHEN NOT COALESCE(
                mcf.tax_info_found,
                FALSE
            )
                THEN NULL

            ELSE COALESCE(
                mcf.ip_status,
                FALSE
            )
        END AS have_ip_status,

        CASE
            WHEN NOT COALESCE(
                ofl.mpr_started,
                FALSE
            )
                THEN NULL

            WHEN NOT COALESCE(
                mcf.tax_info_found,
                FALSE
            )
                THEN NULL

            ELSE COALESCE(
                mcf.self_employed_status,
                FALSE
            )
        END AS have_self_employed_status,

        COALESCE(
            mcf.have_inn_problem,
            FALSE
        ) AS have_inn_problem,

        CASE
            WHEN NOT COALESCE(
                ofl.mpr_started,
                FALSE
            )
                THEN 'МПР не запускался'

            WHEN NOT COALESCE(
                mcf.tax_info_found,
                FALSE
            )
                THEN 'Статус не получен'

            WHEN mcf.ip_status IS TRUE
             AND mcf.self_employed_status IS TRUE
                THEN 'ИП и самозанятый'

            WHEN mcf.ip_status IS TRUE
                THEN 'ИП'

            WHEN mcf.self_employed_status IS TRUE
                THEN 'Самозанятый'

            ELSE 'Физическое лицо'
        END AS tax_status_group,

        /* ПДН */
        mcf.mpr_pdn,
        mcf.mpr_income,
        mcf.mpr_smp1,

        ppdn.calculated_pdn,
        ppdn.calculated_pdn_income,
        ppdn.calculated_smp1,
        ppdn.calculated_smp2,

        COALESCE(
            ppdn.calculated_pdn,
            mcf.mpr_pdn
        ) AS pdn_for_analysis,

        CASE
            WHEN COALESCE(
                ppdn.calculated_pdn,
                mcf.mpr_pdn
            ) IS NULL
                THEN 'ПДН не рассчитан'

            WHEN COALESCE(
                ppdn.calculated_pdn,
                mcf.mpr_pdn
            ) < 50
                THEN 'ПДН < 50'

            WHEN COALESCE(
                ppdn.calculated_pdn,
                mcf.mpr_pdn
            ) < 80
                THEN 'ПДН 50–80'

            WHEN COALESCE(
                ppdn.calculated_pdn,
                mcf.mpr_pdn
            ) < 120
                THEN 'ПДН 80–120'

            ELSE 'ПДН 120+'
        END AS pdn_group,

        CASE
            WHEN ppdn.calculated_pdn IS NOT NULL
             AND mcf.mpr_pdn IS NOT NULL

            THEN ROUND(
                ppdn.calculated_pdn::numeric
                - mcf.mpr_pdn::numeric,
                2
            )
        END AS pdn_difference,

        /* ПСК */
        psk.over_limit_loans_cnt,
        psk.psk_passed,

        CASE
            WHEN psk.over_limit_loans_cnt IS NULL
                THEN 'ПСК не проверена'

            WHEN psk.over_limit_loans_cnt < 2
                THEN 'ПСК пройдена'

            ELSE 'ПСК не пройдена'
        END AS psk_result_group,

        /* Предварительная причина входа в МПР */
        CASE
            WHEN NOT COALESCE(
                ofl.mpr_started,
                FALSE
            )
                THEN 'МПР не запускался'

            WHEN psk.psk_passed IS FALSE
             AND COALESCE(
                 ppdn.calculated_pdn,
                 mcf.mpr_pdn
             ) >= 50
                THEN 'Не пройдены ПСК и ПДН/МПЛ'

            WHEN psk.psk_passed IS FALSE
                THEN 'Не пройдена ПСК'

            WHEN COALESCE(
                ppdn.calculated_pdn,
                mcf.mpr_pdn
            ) >= 80
                THEN 'ПДН 80+'

            WHEN COALESCE(
                ppdn.calculated_pdn,
                mcf.mpr_pdn
            ) >= 50
                THEN 'ПДН 50–80 / МПЛ или иная причина'

            ELSE 'Иная причина входа в МПР'
        END AS mpr_entry_reason_group,

        /* Первое действие */
        sel.first_target_event_id,
        sel.first_target_event_dt,
        sel.first_target_operation,
        sel.first_target_family,
        sel.first_target_group,

        sel.selected_solution_codes,
        sel.selected_solution_names,
        sel.selected_solution_family,
        sel.selection_method,

        COALESCE(
            sel.product_solution_selected,
            FALSE
        ) AS product_solution_selected,

        COALESCE(
            sel.intermediate_solution_selected,
            FALSE
        ) AS intermediate_solution_selected,

        COALESCE(
            sel.selection_ambiguous,
            FALSE
        ) AS selection_ambiguous,

        /* Лучший исход выбранного решения */
        bsa.application_id
            AS selected_application_id,

        bsa.application_dt
            AS selected_application_dt,

        bsa.kind_of_operation
            AS selected_application_operation,

        REGEXP_REPLACE(
    bsa.application_refusal_reason,
    E'[\\r\\n\\t]+',
    ' ',
    'g'
) AS selected_application_refusal_reason,

        bsa.contract_id
            AS selected_contract_id,

        bsa.contract_dt
            AS selected_contract_dt,

        bsa.contract_marker_delete
            AS selected_contract_marker_delete,

        bsa.contract_amount
            AS selected_contract_amount,

        bsa.first_issue_dt
            AS selected_first_issue_dt,

        bsa.first_issue_amount
            AS selected_first_issue_amount,

        bsa.issue_amount_3d
            AS selected_issue_amount_3d,

        bsa.issue_count_3d
            AS selected_issue_count_3d,

        COALESCE(
            bsa.have_issue_3d,
            FALSE
        ) AS selected_have_issue_3d,

        bsa.application_final_result
            AS selected_final_result,

        /* Общий лучший исход клиента */
        bca.event_id
            AS best_application_id,

        bca.target_event_dt
            AS best_application_dt,

        bca.kind_of_operation
            AS best_application_operation,

        REGEXP_REPLACE(
    bca.application_refusal_reason,
    E'[\\r\\n\\t]+',
    ' ',
    'g'
) AS best_application_refusal_reason,

        bca.contract_id,
        bca.contract_code,
        bca.contract_dt,
        bca.contract_marker_delete,
        bca.contract_amount,

        bca.first_issue_dt,
        bca.first_issue_amount,
        bca.issue_amount_3d,
        bca.issue_count_3d,

        COALESCE(
            bca.have_tranche_flag,
            FALSE
        ) AS have_tranche_flag,

        COALESCE(
            bca.have_prolong_flag,
            FALSE
        ) AS have_prolong_flag,

        COALESCE(
            bca.have_renewal_flag,
            FALSE
        ) AS have_renewal_flag,

        COALESCE(
            bca.have_refinance_flag,
            FALSE
        ) AS have_refinance_flag,

        COALESCE(
            bca.have_first_tranche_3d,
            FALSE
        ) AS have_first_tranche_3d,

        COALESCE(
            bca.have_regular_issue_3d,
            FALSE
        ) AS have_regular_issue_3d,

        COALESCE(
            bca.have_issue_3d,
            FALSE
        ) AS have_issue_3d,

        COALESCE(
            bca.result_mature,
            FALSE
        ) AS result_mature,

        COALESCE(
            bca.application_final_result,
            'Продуктовая заявка не создана'
        ) AS final_result,

        /* Совпадение итоговой заявки с предложениями */
        baom.final_matched_offered_solutions,
        CASE
    WHEN NOT COALESCE(ofl.mpr_started, FALSE)
        THEN 'МПР не запускался'

    ELSE baom.final_offer_match_method
END AS final_offer_match_method,

        CASE
    WHEN NOT COALESCE(ofl.mpr_started, FALSE)
        THEN NULL

    ELSE COALESCE(
        baom.final_application_matches_any_offer,
        FALSE
    )
END AS final_application_matches_any_offer,
        
      CASE
    WHEN NOT COALESCE(ofl.mpr_started, FALSE)
        THEN NULL

    ELSE COALESCE(
        baom.final_offer_match_ambiguous,
        FALSE
    )
END AS final_offer_match_ambiguous,
        /* Маршрут клиента */
        CASE
            WHEN bca.event_id IS NULL
                THEN 'Продуктовая заявка не создана'

            WHEN ap.preapplication_id IS NULL
              OR bca.target_event_dt <=
                 ap.preapplication_dt
                THEN 'Без предшествующей Предзаявки'

            WHEN bsa.application_id =
                 bca.event_id
                THEN 'Первое выбранное решение МПР'

            WHEN COALESCE(
                baom.final_application_matches_any_offer,
                FALSE
            )
                THEN 'Другое предложенное решение МПР'

            WHEN COALESCE(
                ofl.mpr_started,
                FALSE
            )
                THEN 'Оформление вне решений МПР'

            WHEN COALESCE(
                ap.preapplication_refused,
                FALSE
            )
                THEN 'После отказанной Предзаявки'

            WHEN NOT COALESCE(
                ap.preapplication_finished,
                FALSE
            )
                THEN 'После брошенной Предзаявки'

            WHEN COALESCE(
                ap.preapplication_success,
                FALSE
            )
                THEN 'Стандартный путь после Предзаявки'

            ELSE 'Другой путь после Предзаявки'
        END AS route_source,

        /* Аномалии */
        (
            COALESCE(
                bca.have_issue_3d,
                FALSE
            )
            AND COALESCE(
                bca.contract_marker_delete,
                FALSE
            )
        ) AS anomaly_issue_deleted_contract,

        (
            ofl.mpr_result_group =
                'Только банкротство'

            AND COALESCE(
                bca.have_issue_3d,
                FALSE
            )
        ) AS anomaly_issue_after_bankruptcy,

        (
            COALESCE(
                ofl.mpr_started,
                FALSE
            )
            AND NOT COALESCE(
                baom.final_application_matches_any_offer,
                FALSE
            )
            AND COALESCE(
                bca.have_issue_3d,
                FALSE
            )
        ) AS anomaly_issue_outside_mpr_solution,

        (
            cd.preapplication_count > 1
        ) AS anomaly_multiple_preapplications,

        (
            SELECT COUNT(
                DISTINCT ao.contract_id
            )

            FROM application_outcomes ao

            WHERE ao.event_date =
                  cd.event_date

              AND ao.counterparty_id =
                  cd.counterparty_id

              AND ao.contract_same_day
        ) AS contracts_count_day

    FROM client_days cd

    LEFT JOIN anchor_preapplication ap
        ON ap.event_date = cd.event_date
       AND ap.counterparty_id =
           cd.counterparty_id

    LEFT JOIN offer_flags ofl
        ON ofl.event_date = cd.event_date
       AND ofl.counterparty_id =
           cd.counterparty_id
       AND ofl.preapplication_id =
           ap.preapplication_id

    LEFT JOIN mpr_client_features mcf
        ON mcf.preapplication_id =
           ap.preapplication_id

    LEFT JOIN preapplication_pdn ppdn
        ON ppdn.preapplication_id =
           ap.preapplication_id

    LEFT JOIN preapplication_psk psk
        ON psk.preapplication_id =
           ap.preapplication_id

    LEFT JOIN selection sel
        ON sel.event_date = cd.event_date
       AND sel.counterparty_id =
           cd.counterparty_id
       AND sel.preapplication_id =
           ap.preapplication_id

    LEFT JOIN best_selected_attempt bsa
        ON bsa.event_date = cd.event_date
       AND bsa.counterparty_id =
           cd.counterparty_id
       AND bsa.preapplication_id =
           ap.preapplication_id

    LEFT JOIN best_client_attempt bca
        ON bca.event_date = cd.event_date
       AND bca.counterparty_id =
           cd.counterparty_id

    LEFT JOIN best_application_offer_match baom
        ON baom.event_date = cd.event_date
       AND baom.counterparty_id =
           cd.counterparty_id
    LEFT JOIN client_profile cp
    ON cp.counterparty_id = cd.counterparty_id
)

/* ============================================================
   Итоговая выгрузка для Excel
   ============================================================ */
SELECT
    e.*,

    /* Общая воронка */
    1::integer AS flag_client_day,

    CASE
        WHEN e.product_application_count > 0 THEN 1
        ELSE 0
    END AS flag_product_application,

    CASE
        WHEN e.contract_id IS NOT NULL THEN 1
        ELSE 0
    END AS flag_contract,

    CASE
        WHEN e.contract_id IS NOT NULL
         AND e.result_mature
        THEN 1 ELSE 0
    END AS flag_mature_contract,

    CASE
        WHEN e.contract_id IS NOT NULL
         AND e.result_mature
         AND e.have_issue_3d
        THEN 1 ELSE 0
    END AS flag_issue_mature,

    CASE
        WHEN e.have_issue_3d THEN 1
        ELSE 0
    END AS flag_issue_all,

    CASE
        WHEN e.contract_id IS NOT NULL
         AND NOT e.result_mature
         AND NOT e.have_issue_3d
        THEN 1 ELSE 0
    END AS flag_contract_waiting,

    /* Воронка Предзаявки */
    CASE
        WHEN e.preapplication_count > 0 THEN 1
        ELSE 0
    END AS flag_preapplication,

    CASE
        WHEN e.preapplication_count > 0
         AND e.preapplication_finished
        THEN 1 ELSE 0
    END AS flag_preapplication_finished,

    CASE
        WHEN e.preapplication_count > 0
         AND e.preapplication_success
        THEN 1 ELSE 0
    END AS flag_preapplication_success,

    CASE
        WHEN e.preapplication_count > 0
         AND e.preapplication_refused
        THEN 1 ELSE 0
    END AS flag_preapplication_refused,

    CASE
        WHEN e.preapplication_count > 0
         AND NOT e.preapplication_finished
        THEN 1 ELSE 0
    END AS flag_preapplication_abandoned,

    /* Воронка МПР */
    CASE
        WHEN e.mpr_started THEN 1
        ELSE 0
    END AS flag_mpr_started,

    CASE
        WHEN e.mpr_started
         AND e.have_product_solution
        THEN 1 ELSE 0
    END AS flag_product_solution,

    CASE
        WHEN e.mpr_started
         AND e.mpr_result_group = 'Нет решений'
        THEN 1 ELSE 0
    END AS flag_mpr_no_solution,

    CASE
        WHEN e.mpr_started
         AND e.have_intermediate_solution
         AND NOT e.have_product_solution
        THEN 1 ELSE 0
    END AS flag_intermediate_only,

    CASE
        WHEN e.mpr_started
         AND e.have_consulting_solution
         AND NOT e.have_product_solution
         AND NOT e.have_intermediate_solution
        THEN 1 ELSE 0
    END AS flag_bankruptcy_only,

    CASE
        WHEN e.product_solution_selected THEN 1
        ELSE 0
    END AS flag_solution_selected,

    CASE
        WHEN e.product_solution_selected
         AND e.selected_contract_id IS NOT NULL
        THEN 1 ELSE 0
    END AS flag_selected_contract,

    CASE
        WHEN e.product_solution_selected
         AND e.selected_contract_id IS NOT NULL
         AND e.selected_contract_dt IS NOT NULL
         AND p.as_of_date > e.selected_contract_dt + 3
        THEN 1 ELSE 0
    END AS flag_selected_mature_contract,

    CASE
        WHEN e.product_solution_selected
         AND e.selected_contract_id IS NOT NULL
         AND e.selected_contract_dt IS NOT NULL
         AND p.as_of_date > e.selected_contract_dt + 3
         AND e.selected_have_issue_3d
        THEN 1 ELSE 0
    END AS flag_selected_issue_mature

FROM excel_data e
CROSS JOIN params p
--where counterparty_id='b8b44768-39db-11ef-b821-3cfdfed12dbc'
ORDER BY
    e.event_date,
    e.tribe,
    e.client_type,
    e.client_code;