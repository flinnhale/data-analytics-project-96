--итоговая таблица с основными метриками

with
tab1 as (
    select
        s.visitor_id,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        date(s.visit_date) as visit_date,
        row_number() over (
            partition by
                s.visitor_id
            order by
                s.visit_date desc
        ) as rn
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in (
            'cpc',
            'cpm',
            'cpa',
            'cpp',
            'tg',
            'youtube',
            'social'
        )
),

last_paid_click as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        cast(count(visitor_id) as numeric) as visitors_count,
        cast(count(lead_id) as numeric) as leads_count,
        date(visit_date) as visit_date,
        count(closing_reason) filter (
            where
            status_id = 142
        ) as purchases_count,
        sum(amount) as revenue
    from
        tab1
    where
        rn = 1
    group by
        6,
        1,
        2,
        3
),

ads as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        1,
        2,
        3,
        4
    union all
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        1,
        2,
        3,
        4
    order by
        1
)

select
    lpc.visit_date,
    lpc.utm_source,
    case
        when sum(lpc.visitors_count) = 0 then 0
        else round(sum(ads.total_cost) / sum(lpc.visitors_count), 2)
    end as cpu,
    case
        when sum(lpc.leads_count) = 0 then 0
        else round(sum(ads.total_cost) / sum(lpc.leads_count), 2)
    end as cpl,
    case
        when sum(lpc.purchases_count) = 0 then 0
        else
            round(
                sum(ads.total_cost) / sum(lpc.purchases_count),
                2
            )
    end as cppu,
    case
        when sum(ads.total_cost) = 0 then 0
        else
            coalesce(
                round(
                    (sum(lpc.revenue) - sum(ads.total_cost))
                    * 100.00
                    / sum(ads.total_cost),
                    2
                ),
                0
            )
    end as roi
from
    last_paid_click as lpc
left join ads
    on
        lpc.utm_source = ads.utm_source
        and lpc.utm_medium = ads.utm_medium
        and lpc.utm_campaign = ads.utm_campaign
        and lpc.visit_date = ads.campaign_date
where
    lpc.utm_source in ('yandex', 'vk')
group by
    1,
    2
order by
    1,
    5 desc nulls last;


-- конверсия из посетителя в лида, из лида в оплату

with
tab1 as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by
                s.visitor_id
            order by
                s.visit_date desc
        ) as rn
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in (
            'cpc',
            'cpm',
            'cpa',
            'cpp',
            'tg',
            'youtube',
            'social'
        )
),

last_paid_click as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        cast(count(visitor_id) as numeric) as visitors_count,
        cast(count(lead_id) as numeric) as leads_count,
        date(visit_date) as visit_date,
        count(closing_reason) filter (
            where
            status_id = 142
        ) as purchases_count,
        sum(amount) as revenue
    from
        tab1
    where
        rn = 1
    group by
        6,
        1,
        2,
        3
)

select
    utm_source,
    sum(visitors_count) as visitors_count,
    sum(leads_count) as leads_count,
    sum(purchases_count) as purchases_count,
    round(sum(leads_count) * 100.0 / sum(visitors_count), 2) as click_to_lead,
    round(
        sum(purchases_count) * 100.0 / sum(leads_count),
        2
    ) as lead_to_paid
from
    last_paid_click
where
    utm_source in ('yandex', 'vk')
group by
    1
order by
    6;


-- ежедневные расходы на рекламу

select
    date(campaign_date) as spend_day,
    utm_source,
    sum(daily_spent) as total_spent
from
    vk_ads
group by
    1,
    2
union all
select
    date(campaign_date) as spend_day,
    utm_source,
    sum(daily_spent) as total_spent
from
    ya_ads
group by
    1,
    2
order by
    1,
    2;


-- смотрим через сколько дней закрывается 90% лидов

with
tab1 as (
    select
        s.visitor_id,
        max(s.visit_date) as mx_visit
    from
        sessions as s
    where
        s.medium in (
            'cpc',
            'cpm',
            'cpa',
            'cpp',
            'tg',
            'youtube',
            'social'
        )
    group by
        1
),

tab2 as (
    select
        s.visit_date,
        s.lead_id,
        l.created_at,
        l.closing_reason,
        l.status_id
    from
        tab1 as t
    inner join sessions as s
        on
            t.visitor_id = s.visitor_id
            and t.mx_visit = s.visit_date
    left join leads as l
        on
            t.visitor_id = l.visitor_id
            and t.mx_visit <= l.created_at
    where
        s.medium in (
            'cpc',
            'cpm',
            'cpa',
            'cpp',
            'tg',
            'youtube',
            'social'
        )
        and l.status_id = 142
)

select
    percentile_disc(0.9) within group (
        order by
            date_trunc('day', created_at - visit_date)
    ) as days_for_close
from
    tab2;


-- окупаемость каналов

with
tab1 as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by
                s.visitor_id
            order by
                s.visit_date desc
        ) as rn
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in (
            'cpc',
            'cpm',
            'cpa',
            'cpp',
            'tg',
            'youtube',
            'social'
        )
),

last_paid_click as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        cast(count(visitor_id) as numeric) as visitors_count,
        cast(count(lead_id) as numeric) as leads_count,
        date(visit_date) as visit_date,
        count(closing_reason) filter (
            where
            status_id = 142
        ) as purchases_count,
        sum(amount) as revenue
    from
        tab1
    where
        rn = 1
    group by
        6,
        1,
        2,
        3
),

ads as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        1,
        2,
        3,
        4
    union all
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        1,
        2,
        3,
        4
    order by
        1
)

select
    lpc.utm_source,
    sum(ads.total_cost) as total_cost,
    sum(lpc.revenue) as total_revenue,
    sum(lpc.revenue) - sum(ads.total_cost) as profit
from
    last_paid_click as lpc
left join ads
    on
        lpc.utm_source = ads.utm_source
        and lpc.utm_medium = ads.utm_medium
        and lpc.utm_campaign = ads.utm_campaign
        and lpc.visit_date = ads.campaign_date
where
    lpc.utm_source in ('yandex', 'vk')
group by
    1
order by
    1 desc nulls last;
