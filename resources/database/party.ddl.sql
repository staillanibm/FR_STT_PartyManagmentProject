CREATE TABLE public.party (
	id bpchar(36) NOT NULL,
	"name" varchar(255) NOT NULL,
	"type" varchar(10) NOT NULL,
	status varchar(10) NOT NULL,
	created_at timestamp NOT NULL,
	updated_at timestamp NULL,
	CONSTRAINT party_pk PRIMARY KEY (id)
);