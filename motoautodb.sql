--
-- PostgreSQL database dump
--

-- Dumped from database version 17.0
-- Dumped by pg_dump version 17.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: book_time_slot(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.book_time_slot(client_id integer, slot_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- Проверка доступности временного слота
    IF EXISTS (
        SELECT 1 
        FROM time_slots 
        WHERE time_slots.slot_id = $2 -- Явное указание, что это второй аргумент функции
          AND is_booked = FALSE
    ) THEN
        -- Обновление статуса временного слота
        UPDATE time_slots
        SET is_booked = TRUE
        WHERE time_slots.slot_id = $2; -- Явное указание, что это второй аргумент функции

        -- Создание записи о бронировании
        INSERT INTO bookings (client_id, slot_id)
        VALUES ($1, $2); -- Использование порядковых аргументов функции
    ELSE
        RAISE EXCEPTION 'Selected time slot is not available';
    END IF;
END;
$_$;


ALTER FUNCTION public.book_time_slot(client_id integer, slot_id integer) OWNER TO postgres;

--
-- Name: create_time_slots(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_time_slots(master_id integer, place_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_day DATE := CURRENT_DATE; 
    slot_start TIMESTAMP;
    slot_end TIMESTAMP;
    day_counter INT;
BEGIN
    FOR day_counter IN 0..9 LOOP 
        FOR slot_start, slot_end IN
            SELECT 
                ts::TIMESTAMP, 
                (ts::TIMESTAMP + INTERVAL '1 hour') 
            FROM UNNEST(ARRAY[
                current_day::TIMESTAMP + INTERVAL '10:00',
                current_day::TIMESTAMP + INTERVAL '12:00',
                current_day::TIMESTAMP + INTERVAL '14:00'
            ]) AS ts
        LOOP
            INSERT INTO time_slots (place_id, master_id, start_time, end_time)
            VALUES (place_id, master_id, slot_start, slot_end);
        END LOOP;
        current_day := current_day + INTERVAL '1 day';
    END LOOP;
END;
$$;


ALTER FUNCTION public.create_time_slots(master_id integer, place_id integer) OWNER TO postgres;

--
-- Name: set_bonus_based_on_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_bonus_based_on_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.client_status = 'Обычный' THEN
        NEW.bonus := 0;
    ELSIF NEW.client_status = 'Постоянный' THEN
        NEW.bonus := 10;
    ELSIF NEW.client_status = 'Премиум' THEN
        NEW.bonus := 25;
    ELSE
        NEW.bonus := 0; 
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_bonus_based_on_status() OWNER TO postgres;

--
-- Name: update_emp_count(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_emp_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE places
    SET emp_count = (
        SELECT COUNT(*) 
        FROM where_works ww 
        WHERE ww.place_id = NEW.place_id
    )
    WHERE place_id = NEW.place_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_emp_count() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bookings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bookings (
    booking_id integer NOT NULL,
    client_id integer,
    slot_id integer,
    booking_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(20) DEFAULT 'Active'::character varying
);


ALTER TABLE public.bookings OWNER TO postgres;

--
-- Name: bookings_booking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bookings_booking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bookings_booking_id_seq OWNER TO postgres;

--
-- Name: bookings_booking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bookings_booking_id_seq OWNED BY public.bookings.booking_id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    client_id integer NOT NULL,
    first_name character varying(255) NOT NULL,
    middle_name character varying(255),
    last_name character varying(255) NOT NULL,
    email character varying(255),
    phone_number character varying(20),
    client_status character varying(20) NOT NULL,
    bonus integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: clients_client_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clients_client_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.clients_client_id_seq OWNER TO postgres;

--
-- Name: clients_client_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clients_client_id_seq OWNED BY public.clients.client_id;


--
-- Name: details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.details (
    detail_id integer NOT NULL,
    detail_info character varying(500) NOT NULL,
    price money NOT NULL,
    detail_type character varying(10)
);


ALTER TABLE public.details OWNER TO postgres;

--
-- Name: details_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.details_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.details_detail_id_seq OWNER TO postgres;

--
-- Name: details_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.details_detail_id_seq OWNED BY public.details.detail_id;


--
-- Name: details_in_places; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.details_in_places (
    detail_id integer,
    place_id integer
);


ALTER TABLE public.details_in_places OWNER TO postgres;

--
-- Name: employers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employers (
    employer_id integer NOT NULL,
    city character varying(100) NOT NULL,
    first_name character varying(255) NOT NULL,
    middle_name character varying(255),
    last_name character varying(255) NOT NULL,
    email character varying(255),
    phone_number character varying(20),
    expirience integer,
    age integer NOT NULL,
    profession_id integer,
    employer_info character varying(500)
);


ALTER TABLE public.employers OWNER TO postgres;

--
-- Name: employers_employer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.employers_employer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.employers_employer_id_seq OWNER TO postgres;

--
-- Name: employers_employer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.employers_employer_id_seq OWNED BY public.employers.employer_id;


--
-- Name: order_part_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_part_details (
    order_id integer,
    detail_id integer,
    amount integer NOT NULL
);


ALTER TABLE public.order_part_details OWNER TO postgres;

--
-- Name: order_part_services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_part_services (
    service_id integer,
    detail_id integer,
    amount integer NOT NULL
);


ALTER TABLE public.order_part_services OWNER TO postgres;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    order_id integer NOT NULL,
    client_id integer,
    employer_id integer,
    place_id integer,
    deadline date,
    order_status character varying(100),
    final_price money
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_order_id_seq OWNER TO postgres;

--
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- Name: places; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.places (
    place_id integer NOT NULL,
    city character varying(255) NOT NULL,
    adress character varying(255) NOT NULL,
    post_code character varying(20),
    phone_number character varying(20),
    emp_count integer
);


ALTER TABLE public.places OWNER TO postgres;

--
-- Name: places_place_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.places_place_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.places_place_id_seq OWNER TO postgres;

--
-- Name: places_place_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.places_place_id_seq OWNED BY public.places.place_id;


--
-- Name: places_service_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.places_service_type (
    place_id integer,
    service_type character varying(10) NOT NULL
);


ALTER TABLE public.places_service_type OWNER TO postgres;

--
-- Name: professions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.professions (
    profession_id integer NOT NULL,
    profession character varying(100) NOT NULL,
    salary integer NOT NULL
);


ALTER TABLE public.professions OWNER TO postgres;

--
-- Name: professions_profession_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.professions_profession_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.professions_profession_id_seq OWNER TO postgres;

--
-- Name: professions_profession_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.professions_profession_id_seq OWNED BY public.professions.profession_id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services (
    service_id integer NOT NULL,
    info character varying(500) NOT NULL,
    service_type character varying(10),
    price money,
    work_time time without time zone
);


ALTER TABLE public.services OWNER TO postgres;

--
-- Name: services_in_places; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services_in_places (
    service_id integer,
    place_id integer
);


ALTER TABLE public.services_in_places OWNER TO postgres;

--
-- Name: services_service_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.services_service_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.services_service_id_seq OWNER TO postgres;

--
-- Name: services_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_service_id_seq OWNED BY public.services.service_id;


--
-- Name: time_slots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.time_slots (
    slot_id integer NOT NULL,
    place_id integer,
    master_id integer,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone NOT NULL,
    is_booked boolean DEFAULT false
);


ALTER TABLE public.time_slots OWNER TO postgres;

--
-- Name: time_slots_slot_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.time_slots_slot_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.time_slots_slot_id_seq OWNER TO postgres;

--
-- Name: time_slots_slot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.time_slots_slot_id_seq OWNED BY public.time_slots.slot_id;


--
-- Name: where_works; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.where_works (
    place_id integer,
    employer_id integer,
    city character varying(100)
);


ALTER TABLE public.where_works OWNER TO postgres;

--
-- Name: bookings booking_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings ALTER COLUMN booking_id SET DEFAULT nextval('public.bookings_booking_id_seq'::regclass);


--
-- Name: clients client_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients ALTER COLUMN client_id SET DEFAULT nextval('public.clients_client_id_seq'::regclass);


--
-- Name: details detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details ALTER COLUMN detail_id SET DEFAULT nextval('public.details_detail_id_seq'::regclass);


--
-- Name: employers employer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employers ALTER COLUMN employer_id SET DEFAULT nextval('public.employers_employer_id_seq'::regclass);


--
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- Name: places place_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places ALTER COLUMN place_id SET DEFAULT nextval('public.places_place_id_seq'::regclass);


--
-- Name: professions profession_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professions ALTER COLUMN profession_id SET DEFAULT nextval('public.professions_profession_id_seq'::regclass);


--
-- Name: services service_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN service_id SET DEFAULT nextval('public.services_service_id_seq'::regclass);


--
-- Name: time_slots slot_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_slots ALTER COLUMN slot_id SET DEFAULT nextval('public.time_slots_slot_id_seq'::regclass);


--
-- Data for Name: bookings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bookings (booking_id, client_id, slot_id, booking_time, status) FROM stdin;
1	1	1	2024-12-22 01:49:51.010974	Active
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (client_id, first_name, middle_name, last_name, email, phone_number, client_status, bonus) FROM stdin;
1	Александр	Иванович	Смирнов	alex.smirnov@example.com	+79161234567	Обычный	0
2	Екатерина	Сергеевна	Иванова	ekaterina.ivanova@example.com	+79261234568	Постоянный	0
3	Дмитрий	Алексеевич	Кузнецов	dmitry.kuznetsov@example.com	+79371234569	Премиум	0
4	Ольга	Владимировна	Федорова	olga.fedorova@example.com	+79481234570	Обычный	0
\.


--
-- Data for Name: details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.details (detail_id, detail_info, price, detail_type) FROM stdin;
1	Гайка	$50.00	Мото
2	Гайка	$50.00	Авто
3	Заряженный турбированный V12	$1,000.00	Мото
\.


--
-- Data for Name: details_in_places; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.details_in_places (detail_id, place_id) FROM stdin;
1	1
3	1
2	2
2	3
1	4
1	5
\.


--
-- Data for Name: employers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employers (employer_id, city, first_name, middle_name, last_name, email, phone_number, expirience, age, profession_id, employer_info) FROM stdin;
1	Москва	Иван	Сергеевич	Петров	ivan.petrov@example.com	+79161234567	10	35	1	Опытный администратор автосервиса
2	Санкт-Петербург	Ольга	Игоревна	Смирнова	olga.smirnova@example.com	+79261234568	5	29	2	Специалист по аналитике данных
3	Москва	Алексей	Николаевич	Кузнецов	alexey.kuznetsov@example.com	+79371234569	8	33	4	Управляет клиентами и заказами автосервиса
4	Москва	Сергей	Андреевич	Васильев	sergey.vasilyev@example.com	+79161234570	7	40	3	Специалист по ремонту двигателей
5	Москва	Дмитрий	Петрович	Сидоров	dmitry.sidorov@example.com	+79161234571	4	28	3	Механик по работе с подвеской
6	Санкт-Петербург	Анна	Алексеевна	Фёдорова	anna.fedorova@example.com	+79261234572	6	32	3	Специалист по шиномонтажу
7	Санкт-Петербург	Виктор	Владимирович	Михайлов	victor.mikhailov@example.com	+79261234573	3	25	3	Мастер по диагностике электроники
\.


--
-- Data for Name: order_part_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_part_details (order_id, detail_id, amount) FROM stdin;
1	1	1
\.


--
-- Data for Name: order_part_services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_part_services (service_id, detail_id, amount) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (order_id, client_id, employer_id, place_id, deadline, order_status, final_price) FROM stdin;
1	1	5	1	2024-12-22	В процессе	\N
\.


--
-- Data for Name: places; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.places (place_id, city, adress, post_code, phone_number, emp_count) FROM stdin;
1	Москва	Новослобская, д30	111252	88005553535	\N
2	Москва	Красные ворота, д5	111474	88005559999	\N
3	Москва	Южные Сахалины, д666	111838	88005557676	\N
5	Санкт-Петербург	Слабая южная, д100	222888	89009994545	\N
4	Санкт-Петербург	Малая умная, д99	222666	89009997373	2
\.


--
-- Data for Name: places_service_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.places_service_type (place_id, service_type) FROM stdin;
1	Мото
2	Авто
3	Авто
4	Мото
5	Авто
\.


--
-- Data for Name: professions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.professions (profession_id, profession, salary) FROM stdin;
1	Администратор	100000
2	Аналитик	90000
3	Мастер	50000
4	Менеджер	70000
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (service_id, info, service_type, price, work_time) FROM stdin;
1	Мотоцикл чинит	Мото	$1,500.00	00:30:00
2	Двигатель мото чинит	Мото	$2,500.00	01:00:00
3	Машина чинит	Авто	$7,000.00	00:45:00
4	Двигатель машина чинит	Авто	$3,500.00	02:00:00
\.


--
-- Data for Name: services_in_places; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services_in_places (service_id, place_id) FROM stdin;
1	1
2	1
3	2
4	3
1	4
4	5
\.


--
-- Data for Name: time_slots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.time_slots (slot_id, place_id, master_id, start_time, end_time, is_booked) FROM stdin;
2	1	4	2024-12-22 10:00:00	2024-12-22 11:00:00	f
3	2	5	2024-12-22 09:00:00	2024-12-22 10:30:00	f
4	2	5	2024-12-22 11:00:00	2024-12-22 12:30:00	f
5	1	5	2024-12-22 10:00:00	2024-12-22 11:00:00	f
6	1	5	2024-12-22 12:00:00	2024-12-22 13:00:00	f
7	1	5	2024-12-22 14:00:00	2024-12-22 15:00:00	f
8	1	5	2024-12-23 10:00:00	2024-12-23 11:00:00	f
9	1	5	2024-12-23 12:00:00	2024-12-23 13:00:00	f
10	1	5	2024-12-23 14:00:00	2024-12-23 15:00:00	f
11	1	5	2024-12-24 10:00:00	2024-12-24 11:00:00	f
12	1	5	2024-12-24 12:00:00	2024-12-24 13:00:00	f
13	1	5	2024-12-24 14:00:00	2024-12-24 15:00:00	f
14	1	5	2024-12-25 10:00:00	2024-12-25 11:00:00	f
15	1	5	2024-12-25 12:00:00	2024-12-25 13:00:00	f
16	1	5	2024-12-25 14:00:00	2024-12-25 15:00:00	f
17	1	5	2024-12-26 10:00:00	2024-12-26 11:00:00	f
18	1	5	2024-12-26 12:00:00	2024-12-26 13:00:00	f
19	1	5	2024-12-26 14:00:00	2024-12-26 15:00:00	f
20	1	5	2024-12-27 10:00:00	2024-12-27 11:00:00	f
21	1	5	2024-12-27 12:00:00	2024-12-27 13:00:00	f
22	1	5	2024-12-27 14:00:00	2024-12-27 15:00:00	f
23	1	5	2024-12-28 10:00:00	2024-12-28 11:00:00	f
24	1	5	2024-12-28 12:00:00	2024-12-28 13:00:00	f
25	1	5	2024-12-28 14:00:00	2024-12-28 15:00:00	f
26	1	5	2024-12-29 10:00:00	2024-12-29 11:00:00	f
27	1	5	2024-12-29 12:00:00	2024-12-29 13:00:00	f
28	1	5	2024-12-29 14:00:00	2024-12-29 15:00:00	f
29	1	5	2024-12-30 10:00:00	2024-12-30 11:00:00	f
30	1	5	2024-12-30 12:00:00	2024-12-30 13:00:00	f
31	1	5	2024-12-30 14:00:00	2024-12-30 15:00:00	f
32	1	5	2024-12-31 10:00:00	2024-12-31 11:00:00	f
33	1	5	2024-12-31 12:00:00	2024-12-31 13:00:00	f
34	1	5	2024-12-31 14:00:00	2024-12-31 15:00:00	f
1	1	4	2024-12-22 09:00:00	2024-12-22 10:00:00	t
\.


--
-- Data for Name: where_works; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.where_works (place_id, employer_id, city) FROM stdin;
1	4	\N
2	5	\N
3	5	\N
4	6	\N
5	7	\N
4	7	\N
\.


--
-- Name: bookings_booking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bookings_booking_id_seq', 1, true);


--
-- Name: clients_client_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_client_id_seq', 4, true);


--
-- Name: details_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.details_detail_id_seq', 3, true);


--
-- Name: employers_employer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.employers_employer_id_seq', 7, true);


--
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_order_id_seq', 1, true);


--
-- Name: places_place_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.places_place_id_seq', 5, true);


--
-- Name: professions_profession_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.professions_profession_id_seq', 4, true);


--
-- Name: services_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_service_id_seq', 4, true);


--
-- Name: time_slots_slot_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.time_slots_slot_id_seq', 34, true);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (booking_id);


--
-- Name: clients clients_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_phone_number_key UNIQUE (phone_number);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- Name: details details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details
    ADD CONSTRAINT details_pkey PRIMARY KEY (detail_id);


--
-- Name: employers employers_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employers
    ADD CONSTRAINT employers_phone_number_key UNIQUE (phone_number);


--
-- Name: employers employers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employers
    ADD CONSTRAINT employers_pkey PRIMARY KEY (employer_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_pkey PRIMARY KEY (place_id);


--
-- Name: professions professions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.professions
    ADD CONSTRAINT professions_pkey PRIMARY KEY (profession_id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


--
-- Name: time_slots time_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_pkey PRIMARY KEY (slot_id);


--
-- Name: where_works emp_count_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER emp_count_trigger AFTER INSERT OR DELETE OR UPDATE ON public.where_works FOR EACH ROW EXECUTE FUNCTION public.update_emp_count();


--
-- Name: clients set_bonus_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_bonus_trigger BEFORE INSERT OR UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.set_bonus_based_on_status();


--
-- Name: bookings bookings_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(client_id) ON DELETE CASCADE;


--
-- Name: bookings bookings_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.time_slots(slot_id) ON DELETE CASCADE;


--
-- Name: details_in_places details_in_places_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details_in_places
    ADD CONSTRAINT details_in_places_detail_id_fkey FOREIGN KEY (detail_id) REFERENCES public.details(detail_id);


--
-- Name: details_in_places details_in_places_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.details_in_places
    ADD CONSTRAINT details_in_places_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(place_id);


--
-- Name: employers employers_profession_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employers
    ADD CONSTRAINT employers_profession_id_fkey FOREIGN KEY (profession_id) REFERENCES public.professions(profession_id);


--
-- Name: order_part_details order_part_details_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_part_details
    ADD CONSTRAINT order_part_details_detail_id_fkey FOREIGN KEY (detail_id) REFERENCES public.details(detail_id);


--
-- Name: order_part_details order_part_details_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_part_details
    ADD CONSTRAINT order_part_details_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id);


--
-- Name: order_part_services order_part_services_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_part_services
    ADD CONSTRAINT order_part_services_detail_id_fkey FOREIGN KEY (detail_id) REFERENCES public.details(detail_id);


--
-- Name: order_part_services order_part_services_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_part_services
    ADD CONSTRAINT order_part_services_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id);


--
-- Name: orders orders_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(client_id);


--
-- Name: orders orders_employer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_employer_id_fkey FOREIGN KEY (employer_id) REFERENCES public.employers(employer_id);


--
-- Name: orders orders_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(place_id);


--
-- Name: places_service_type places_service_type_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places_service_type
    ADD CONSTRAINT places_service_type_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(place_id);


--
-- Name: services_in_places services_in_places_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_in_places
    ADD CONSTRAINT services_in_places_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(place_id);


--
-- Name: services_in_places services_in_places_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_in_places
    ADD CONSTRAINT services_in_places_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id);


--
-- Name: time_slots time_slots_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_master_id_fkey FOREIGN KEY (master_id) REFERENCES public.employers(employer_id) ON DELETE CASCADE;


--
-- Name: time_slots time_slots_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_slots
    ADD CONSTRAINT time_slots_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(place_id) ON DELETE CASCADE;


--
-- Name: where_works where_works_employer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.where_works
    ADD CONSTRAINT where_works_employer_id_fkey FOREIGN KEY (employer_id) REFERENCES public.employers(employer_id);


--
-- Name: where_works where_works_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.where_works
    ADD CONSTRAINT where_works_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(place_id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO analyst_role;
GRANT USAGE ON SCHEMA public TO master_role;
GRANT USAGE ON SCHEMA public TO manager_role;


--
-- Name: TABLE bookings; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.bookings TO analyst_role;


--
-- Name: TABLE clients; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.clients TO admin_role;
GRANT SELECT ON TABLE public.clients TO analyst_role;
GRANT SELECT,UPDATE ON TABLE public.clients TO master_role;
GRANT SELECT,INSERT,UPDATE ON TABLE public.clients TO manager_role;


--
-- Name: SEQUENCE clients_client_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.clients_client_id_seq TO admin_role;


--
-- Name: TABLE details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.details TO admin_role;
GRANT SELECT ON TABLE public.details TO analyst_role;


--
-- Name: SEQUENCE details_detail_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.details_detail_id_seq TO admin_role;


--
-- Name: TABLE details_in_places; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.details_in_places TO admin_role;
GRANT SELECT ON TABLE public.details_in_places TO analyst_role;


--
-- Name: TABLE employers; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.employers TO admin_role;
GRANT SELECT ON TABLE public.employers TO analyst_role;


--
-- Name: SEQUENCE employers_employer_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.employers_employer_id_seq TO admin_role;


--
-- Name: TABLE order_part_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.order_part_details TO admin_role;
GRANT SELECT ON TABLE public.order_part_details TO analyst_role;


--
-- Name: TABLE order_part_services; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.order_part_services TO admin_role;
GRANT SELECT ON TABLE public.order_part_services TO analyst_role;


--
-- Name: TABLE orders; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.orders TO admin_role;
GRANT SELECT ON TABLE public.orders TO analyst_role;
GRANT SELECT,INSERT,UPDATE ON TABLE public.orders TO master_role;
GRANT SELECT,INSERT,UPDATE ON TABLE public.orders TO manager_role;


--
-- Name: SEQUENCE orders_order_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.orders_order_id_seq TO admin_role;


--
-- Name: TABLE places; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.places TO admin_role;
GRANT SELECT ON TABLE public.places TO analyst_role;


--
-- Name: SEQUENCE places_place_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.places_place_id_seq TO admin_role;


--
-- Name: TABLE places_service_type; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.places_service_type TO admin_role;
GRANT SELECT ON TABLE public.places_service_type TO analyst_role;


--
-- Name: TABLE professions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.professions TO admin_role;
GRANT SELECT ON TABLE public.professions TO analyst_role;


--
-- Name: SEQUENCE professions_profession_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.professions_profession_id_seq TO admin_role;


--
-- Name: TABLE services; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.services TO admin_role;
GRANT SELECT ON TABLE public.services TO analyst_role;


--
-- Name: TABLE services_in_places; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.services_in_places TO admin_role;
GRANT SELECT ON TABLE public.services_in_places TO analyst_role;


--
-- Name: SEQUENCE services_service_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.services_service_id_seq TO admin_role;


--
-- Name: TABLE time_slots; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.time_slots TO analyst_role;


--
-- Name: TABLE where_works; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.where_works TO admin_role;
GRANT SELECT ON TABLE public.where_works TO analyst_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO analyst_role;


--
-- PostgreSQL database dump complete
--

